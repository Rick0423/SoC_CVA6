// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: CVA6 Top-level module


module cva6
  import ariane_pkg::*;
#(
    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg,
    parameter bit IsRVFI = bit'(cva6_config_pkg::CVA6ConfigRvfiTrace),
    // RVFI
    parameter type rvfi_instr_t = struct packed {
      logic [config_pkg::NRET-1:0]                  valid;
      logic [config_pkg::NRET*64-1:0]               order;
      logic [config_pkg::NRET*config_pkg::ILEN-1:0] insn;
      logic [config_pkg::NRET-1:0]                  trap;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      cause;
      logic [config_pkg::NRET-1:0]                  halt;
      logic [config_pkg::NRET-1:0]                  intr;
      logic [config_pkg::NRET*2-1:0]                mode;
      logic [config_pkg::NRET*2-1:0]                ixl;
      logic [config_pkg::NRET*5-1:0]                rs1_addr;
      logic [config_pkg::NRET*5-1:0]                rs2_addr;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      rs1_rdata;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      rs2_rdata;
      logic [config_pkg::NRET*5-1:0]                rd_addr;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      rd_wdata;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      pc_rdata;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      pc_wdata;
      logic [config_pkg::NRET*riscv::VLEN-1:0]      mem_addr;
      logic [config_pkg::NRET*riscv::PLEN-1:0]      mem_paddr;
      logic [config_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_rmask;
      logic [config_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_wmask;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      mem_rdata;
      logic [config_pkg::NRET*riscv::XLEN-1:0]      mem_wdata;
    },
    // AXI types
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    },
    //
    parameter type acc_cfg_t = logic,
    parameter acc_cfg_t AccCfg = '0,

    parameter type cvxif_req_t = cvxif_pkg::cvxif_req_t,
    parameter type cvxif_resp_t = cvxif_pkg::cvxif_resp_t
) (
    input logic clk_i,
    input logic rst_ni,
    // Core ID, Cluster ID and boot address are considered more or less static
    input logic [riscv::VLEN-1:0] boot_addr_i,  // reset boot address
    input  logic [riscv::XLEN-1:0]       hart_id_i,    // hart id in a multicore environment (reflected in a CSR)
    // Interrupt inputs
    input logic [1:0] irq_i,  // level sensitive IR lines, mip & sip (async)
    input logic ipi_i,  // inter-processor interrupts (async)
    // Timer facilities
    input logic time_irq_i,  // timer interrupt in (async)
    input logic debug_req_i,  // debug request (async)
    // RISC-V formal interface port (`rvfi`):
    // Can be left open when formal tracing is not needed.
    output rvfi_instr_t [CVA6Cfg.NrCommitPorts-1:0] rvfi_o,
		
		/********** Commented by Siris Li **********
    output cvxif_req_t cvxif_req_o,
    input cvxif_resp_t cvxif_resp_i,
		********************************************/

    // memory side
    output noc_req_t noc_req_o,
    input noc_resp_t noc_resp_i
);

  // ------------------------------------------
  // CVA6 configuration
  // ------------------------------------------
  // Extended config
  localparam bit RVF = (riscv::IS_XLEN64 | riscv::IS_XLEN32) & CVA6Cfg.FpuEn;
  localparam bit RVD = (riscv::IS_XLEN64 ? 1 : 0) & CVA6Cfg.FpuEn;
  localparam bit FpPresent = RVF | RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
  localparam bit NSX = CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XFVec;  // Are non-standard extensions present?
  localparam int unsigned FLen = RVD ? 64 :  // D ext.
  RVF ? 32 :  // F ext.
  CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
  CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
  CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
  1;  // Unused in case of no FP

  // Transprecision floating-point extensions configuration
  localparam bit RVFVec     = RVF             & CVA6Cfg.XFVec & FLen>32; // FP32 vectors available if vectors and larger fmt enabled
  localparam bit XF16Vec    = CVA6Cfg.XF16    & CVA6Cfg.XFVec & FLen>16; // FP16 vectors available if vectors and larger fmt enabled
  localparam bit XF16ALTVec = CVA6Cfg.XF16ALT & CVA6Cfg.XFVec & FLen>16; // FP16ALT vectors available if vectors and larger fmt enabled
  localparam bit XF8Vec     = CVA6Cfg.XF8     & CVA6Cfg.XFVec & FLen>8;  // FP8 vectors available if vectors and larger fmt enabled

  localparam bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
  localparam int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;

  localparam NrRgprPorts = 2;

  localparam bit NonIdemPotenceEn = CVA6Cfg.NrNonIdempotentRules && CVA6Cfg.NonIdempotentLength;  // Currently only used by V extension (Ara)

  localparam config_pkg::cva6_cfg_t CVA6ExtendCfg = {
    CVA6Cfg.NrCommitPorts,
    CVA6Cfg.AxiAddrWidth,
    CVA6Cfg.AxiDataWidth,
    CVA6Cfg.AxiIdWidth,
    CVA6Cfg.AxiUserWidth,
    CVA6Cfg.NrLoadBufEntries,
    CVA6Cfg.FpuEn,
    CVA6Cfg.XF16,
    CVA6Cfg.XF16ALT,
    CVA6Cfg.XF8,
    CVA6Cfg.RVA,
    CVA6Cfg.RVV,
    CVA6Cfg.RVC,
    CVA6Cfg.RVZCB,
    CVA6Cfg.XFVec,
    CVA6Cfg.CvxifEn,
    CVA6Cfg.ZiCondExtEn,
    // Extended
    bit'(RVF),
    bit'(RVD),
    bit'(FpPresent),
    bit'(NSX),
    unsigned'(FLen),
    bit'(RVFVec),
    bit'(XF16Vec),
    bit'(XF16ALTVec),
    bit'(XF8Vec),
    unsigned'(NrRgprPorts),
    unsigned'(NrWbPorts),
    bit'(EnableAccelerator),
    CVA6Cfg.RVS,
    CVA6Cfg.RVU,
    CVA6Cfg.HaltAddress,
    CVA6Cfg.ExceptionAddress,
    CVA6Cfg.RASDepth,
    CVA6Cfg.BTBEntries,
    CVA6Cfg.BHTEntries,
    CVA6Cfg.DmBaseAddress,
    CVA6Cfg.NrPMPEntries,
    CVA6Cfg.NOCType,
    CVA6Cfg.NrNonIdempotentRules,
    CVA6Cfg.NonIdempotentAddrBase,
    CVA6Cfg.NonIdempotentLength,
    CVA6Cfg.NrExecuteRegionRules,
    CVA6Cfg.ExecuteRegionAddrBase,
    CVA6Cfg.ExecuteRegionLength,
    CVA6Cfg.NrCachedRegionRules,
    CVA6Cfg.CachedRegionAddrBase,
    CVA6Cfg.CachedRegionLength,
    CVA6Cfg.MaxOutstandingStores,
    CVA6Cfg.DebugEn,
    NonIdemPotenceEn,
    CVA6Cfg.AxiBurstWriteEn
  };


  // ------------------------------------------
  // Global Signals
  // Signals connecting more than one module
  // ------------------------------------------
  riscv::priv_lvl_t                                   priv_lvl;
  exception_t                                         ex_commit;  // exception from commit stage
  bp_resolve_t                                        resolved_branch;
  logic             [                riscv::VLEN-1:0] pc_commit;
  logic                                               eret;
  logic             [CVA6ExtendCfg.NrCommitPorts-1:0] commit_ack;

  localparam NumPorts = 4;
  cvxif_pkg::cvxif_req_t cvxif_req;
  cvxif_pkg::cvxif_resp_t cvxif_resp;

  // --------------
  // PCGEN <-> CSR
  // --------------
  logic [riscv::VLEN-1:0] trap_vector_base_commit_pcgen;
  logic [riscv::VLEN-1:0] epc_commit_pcgen;
  // --------------
  // IF <-> ID
  // --------------
  fetch_entry_t fetch_entry_if_id;
  logic fetch_valid_if_id;
  logic fetch_ready_id_if;

  // --------------
  // ID <-> ISSUE
  // --------------
  scoreboard_entry_t issue_entry_id_issue;
  logic issue_entry_valid_id_issue;
  logic is_ctrl_fow_id_issue;
  logic issue_instr_issue_id;

  // --------------
  // ISSUE <-> EX
  // --------------
  logic [riscv::VLEN-1:0] rs1_forwarding_id_ex;  // unregistered version of fu_data_o.operanda
  logic [riscv::VLEN-1:0] rs2_forwarding_id_ex;  // unregistered version of fu_data_o.operandb

  fu_data_t fu_data_id_ex;
  logic [riscv::VLEN-1:0] pc_id_ex;
  logic is_compressed_instr_id_ex;
  // fixed latency units
  logic flu_ready_ex_id;
  logic [TRANS_ID_BITS-1:0] flu_trans_id_ex_id;
  logic flu_valid_ex_id;
  riscv::xlen_t flu_result_ex_id;
  exception_t flu_exception_ex_id;
  // ALU
  logic alu_valid_id_ex;
  // Branches and Jumps
  logic branch_valid_id_ex;

  branchpredict_sbe_t branch_predict_id_ex;
  logic resolve_branch_ex_id;
  // LSU
  logic lsu_valid_id_ex;
  logic lsu_ready_ex_id;

  logic [TRANS_ID_BITS-1:0] load_trans_id_ex_id;
  riscv::xlen_t load_result_ex_id;
  logic load_valid_ex_id;
  exception_t load_exception_ex_id;

  riscv::xlen_t store_result_ex_id;
  logic [TRANS_ID_BITS-1:0] store_trans_id_ex_id;
  logic store_valid_ex_id;
  exception_t store_exception_ex_id;
  // MULT
  logic mult_valid_id_ex;
  // FPU
  logic fpu_ready_ex_id;
  logic fpu_valid_id_ex;
  logic [1:0] fpu_fmt_id_ex;
  logic [2:0] fpu_rm_id_ex;
  logic [TRANS_ID_BITS-1:0] fpu_trans_id_ex_id;
  riscv::xlen_t fpu_result_ex_id;
  logic fpu_valid_ex_id;
  exception_t fpu_exception_ex_id;
  // Accelerator
  logic stall_acc_id;
  scoreboard_entry_t issue_instr_id_acc;
  logic issue_instr_hs_id_acc;
  logic [TRANS_ID_BITS-1:0] acc_trans_id_ex_id;
  riscv::xlen_t acc_result_ex_id;
  logic acc_valid_ex_id;
  exception_t acc_exception_ex_id;
  logic halt_acc_ctrl;
  logic [4:0] acc_resp_fflags;
  logic acc_resp_fflags_valid;
  // CSR
  logic csr_valid_id_ex;
  // CVXIF
  logic [TRANS_ID_BITS-1:0] x_trans_id_ex_id;
  riscv::xlen_t x_result_ex_id;
  logic x_valid_ex_id;
  exception_t x_exception_ex_id;
  logic x_we_ex_id;
  logic x_issue_valid_id_ex;
  logic x_issue_ready_ex_id;
  logic [31:0] x_off_instr_id_ex;
  // --------------
  // EX <-> COMMIT
  // --------------
  // CSR Commit
  logic csr_commit_commit_ex;
  logic dirty_fp_state;
  logic dirty_v_state;
  // LSU Commit
  logic lsu_commit_commit_ex;
  logic lsu_commit_ready_ex_commit;
  logic [TRANS_ID_BITS-1:0] lsu_commit_trans_id;
  logic stall_st_pending_ex;
  logic no_st_pending_ex;
  logic no_st_pending_commit;
  logic amo_valid_commit;
  // ACCEL Commit
  logic acc_valid_acc_ex;
  // --------------
  // ID <-> COMMIT
  // --------------
  scoreboard_entry_t [CVA6ExtendCfg.NrCommitPorts-1:0] commit_instr_id_commit;
  // --------------
  // COMMIT <-> ID
  // --------------
  logic [CVA6ExtendCfg.NrCommitPorts-1:0][4:0] waddr_commit_id;
  logic [CVA6ExtendCfg.NrCommitPorts-1:0][riscv::XLEN-1:0] wdata_commit_id;
  logic [CVA6ExtendCfg.NrCommitPorts-1:0] we_gpr_commit_id;
  logic [CVA6ExtendCfg.NrCommitPorts-1:0] we_fpr_commit_id;
  // --------------
  // CSR <-> *
  // --------------
  logic [4:0] fflags_csr_commit;
  riscv::xs_t fs;
  logic [2:0] frm_csr_id_issue_ex;
  logic [6:0] fprec_csr_ex;
  riscv::xs_t vs;
  logic enable_translation_csr_ex;
  logic en_ld_st_translation_csr_ex;
  riscv::priv_lvl_t ld_st_priv_lvl_csr_ex;
  logic sum_csr_ex;
  logic mxr_csr_ex;
  logic [riscv::PPNW-1:0] satp_ppn_csr_ex;
  logic [ASID_WIDTH-1:0] asid_csr_ex;
  logic [11:0] csr_addr_ex_csr;
  fu_op csr_op_commit_csr;
  riscv::xlen_t csr_wdata_commit_csr;
  riscv::xlen_t csr_rdata_csr_commit;
  exception_t csr_exception_csr_commit;
  logic tvm_csr_id;
  logic tw_csr_id;
  logic tsr_csr_id;
  irq_ctrl_t irq_ctrl_csr_id;
  logic dcache_en_csr_nbdcache;
  logic csr_write_fflags_commit_cs;
  logic icache_en_csr;
  logic acc_cons_en_csr;
  logic debug_mode;
  logic single_step_csr_commit;
  riscv::pmpcfg_t [15:0] pmpcfg;
  logic [15:0][riscv::PLEN-3:0] pmpaddr;
  logic [31:0] mcountinhibit_csr_perf;
  // ----------------------------
  // Performance Counters <-> *
  // ----------------------------
  logic [11:0] addr_csr_perf;
  riscv::xlen_t data_csr_perf, data_perf_csr;
  logic                                                                we_csr_perf;

  logic                                                                icache_flush_ctrl_cache;
  logic                                                                itlb_miss_ex_perf;
  logic                                                                dtlb_miss_ex_perf;
  logic                                                                dcache_miss_cache_perf;
  logic                                                                icache_miss_cache_perf;
  logic          [                 NumPorts-1:0][DCACHE_SET_ASSOC-1:0] miss_vld_bits;
  logic                                                                stall_issue;
  // --------------
  // CTRL <-> *
  // --------------
  logic                                                                set_pc_ctrl_pcgen;
  logic                                                                flush_csr_ctrl;
  logic                                                                flush_unissued_instr_ctrl_id;
  logic                                                                flush_ctrl_if;
  logic                                                                flush_ctrl_id;
  logic                                                                flush_ctrl_ex;
  logic                                                                flush_ctrl_bp;
  logic                                                                flush_tlb_ctrl_ex;
  logic                                                                fence_i_commit_controller;
  logic                                                                fence_commit_controller;
  logic                                                                sfence_vma_commit_controller;
  logic                                                                halt_ctrl;
  logic                                                                halt_csr_ctrl;
  logic                                                                dcache_flush_ctrl_cache;
  logic                                                                dcache_flush_ack_cache_ctrl;
  logic                                                                set_debug_pc;
  logic                                                                flush_commit;
  logic                                                                flush_acc;

  icache_areq_t                                                        icache_areq_ex_cache;
  icache_arsp_t                                                        icache_areq_cache_ex;
  icache_dreq_t                                                        icache_dreq_if_cache;
  icache_drsp_t                                                        icache_dreq_cache_if;

  amo_req_t                                                            amo_req;
  amo_resp_t                                                           amo_resp;
  logic                                                                sb_full;

  // ----------------
  // DCache <-> *
  // ----------------
  dcache_req_i_t [                          2:0]                       dcache_req_ports_ex_cache;
  dcache_req_o_t [                          2:0]                       dcache_req_ports_cache_ex;
  dcache_req_i_t [                          1:0]                       dcache_req_ports_acc_cache;
  dcache_req_o_t [                          1:0]                       dcache_req_ports_cache_acc;
  logic                                                                dcache_commit_wbuffer_empty;
  logic                                                                dcache_commit_wbuffer_not_ni;

  logic          [              riscv::VLEN-1:0]                       lsu_addr;
  logic          [              riscv::PLEN-1:0]                       mem_paddr;
  logic          [          (riscv::XLEN/8)-1:0]                       lsu_rmask;
  logic          [          (riscv::XLEN/8)-1:0]                       lsu_wmask;
  logic          [ariane_pkg::TRANS_ID_BITS-1:0]                       lsu_addr_trans_id;

  // Accelerator port
  logic          [                         63:0]                       inval_addr;
  logic                                                                inval_valid;
  logic                                                                inval_ready;

  // --------------
  // Frontend
  // --------------
  frontend #(
      .CVA6Cfg(CVA6ExtendCfg)
  ) i_frontend (
      .flush_i            (flush_ctrl_if),                  // not entirely correct
      .flush_bp_i         (1'b0),
      .halt_i             (halt_ctrl),
      .debug_mode_i       (debug_mode),
      .boot_addr_i        (boot_addr_i[riscv::VLEN-1:0]),
      .icache_dreq_i      (icache_dreq_cache_if),
      .icache_dreq_o      (icache_dreq_if_cache),
      .resolved_branch_i  (resolved_branch),
      .pc_commit_i        (pc_commit),
      .set_pc_commit_i    (set_pc_ctrl_pcgen),
      .set_debug_pc_i     (set_debug_pc),
      .epc_i              (epc_commit_pcgen),
      .eret_i             (eret),
      .trap_vector_base_i (trap_vector_base_commit_pcgen),
      .ex_valid_i         (ex_commit.valid),
      .fetch_entry_o      (fetch_entry_if_id),
      .fetch_entry_valid_o(fetch_valid_if_id),
      .fetch_entry_ready_i(fetch_ready_id_if),
      .*
  );

  // ---------
  // ID
  // ---------
  id_stage #(
      .CVA6Cfg(CVA6ExtendCfg)
  ) id_stage_i (
      .clk_i,
      .rst_ni,
      .flush_i(flush_ctrl_if),
      .debug_req_i,

      .fetch_entry_i      (fetch_entry_if_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .fetch_entry_ready_o(fetch_ready_id_if),

      .issue_entry_o      (issue_entry_id_issue),
      .issue_entry_valid_o(issue_entry_valid_id_issue),
      .is_ctrl_flow_o     (is_ctrl_fow_id_issue),
      .issue_instr_ack_i  (issue_instr_issue_id),

      .priv_lvl_i  (priv_lvl),
      .fs_i        (fs),
      .frm_i       (frm_csr_id_issue_ex),
      .vs_i        (vs),
      .irq_i       (irq_i),
      .irq_ctrl_i  (irq_ctrl_csr_id),
      .debug_mode_i(debug_mode),
      .tvm_i       (tvm_csr_id),
      .tw_i        (tw_csr_id),
      .tsr_i       (tsr_csr_id)
  );

  logic [NrWbPorts-1:0][TRANS_ID_BITS-1:0] trans_id_ex_id;
  logic [NrWbPorts-1:0][riscv::XLEN-1:0] wbdata_ex_id;
  exception_t [NrWbPorts-1:0] ex_ex_ex_id;  // exception from execute, ex_stage to id_stage
  logic [NrWbPorts-1:0] wt_valid_ex_id;

  if (CVA6ExtendCfg.CvxifEn) begin
    assign trans_id_ex_id = {
      x_trans_id_ex_id,
      flu_trans_id_ex_id,
      load_trans_id_ex_id,
      store_trans_id_ex_id,
      fpu_trans_id_ex_id
    };
    assign wbdata_ex_id = {
      x_result_ex_id, flu_result_ex_id, load_result_ex_id, store_result_ex_id, fpu_result_ex_id
    };
    assign ex_ex_ex_id = {
      x_exception_ex_id,
      flu_exception_ex_id,
      load_exception_ex_id,
      store_exception_ex_id,
      fpu_exception_ex_id
    };
    assign wt_valid_ex_id = {
      x_valid_ex_id, flu_valid_ex_id, load_valid_ex_id, store_valid_ex_id, fpu_valid_ex_id
    };
  end else if (CVA6ExtendCfg.EnableAccelerator) begin
    assign trans_id_ex_id = {
      flu_trans_id_ex_id,
      load_trans_id_ex_id,
      store_trans_id_ex_id,
      fpu_trans_id_ex_id,
      acc_trans_id_ex_id
    };
    assign wbdata_ex_id = {
      flu_result_ex_id, load_result_ex_id, store_result_ex_id, fpu_result_ex_id, acc_result_ex_id
    };
    assign ex_ex_ex_id = {
      flu_exception_ex_id,
      load_exception_ex_id,
      store_exception_ex_id,
      fpu_exception_ex_id,
      acc_exception_ex_id
    };
    assign wt_valid_ex_id = {
      flu_valid_ex_id, load_valid_ex_id, store_valid_ex_id, fpu_valid_ex_id, acc_valid_ex_id
    };
  end else begin
    assign trans_id_ex_id = {
      flu_trans_id_ex_id, load_trans_id_ex_id, store_trans_id_ex_id, fpu_trans_id_ex_id
    };
    assign wbdata_ex_id = {
      flu_result_ex_id, load_result_ex_id, store_result_ex_id, fpu_result_ex_id
    };
    assign ex_ex_ex_id = {
      flu_exception_ex_id, load_exception_ex_id, store_exception_ex_id, fpu_exception_ex_id
    };
    assign wt_valid_ex_id = {flu_valid_ex_id, load_valid_ex_id, store_valid_ex_id, fpu_valid_ex_id};
  end

  if (CVA6ExtendCfg.CvxifEn && CVA6ExtendCfg.EnableAccelerator) begin : gen_err_xif_and_acc
    $error("X-interface and accelerator port cannot be enabled at the same time.");
  end

  // ---------
  // Issue
  // ---------
  issue_stage #(
      .CVA6Cfg   (CVA6ExtendCfg),
      .IsRVFI    (IsRVFI),
      .NR_ENTRIES(NR_SB_ENTRIES)
  ) issue_stage_i (
      .clk_i,
      .rst_ni,
      .sb_full_o             (sb_full),
      .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
      .flush_i               (flush_ctrl_id),
      .stall_i               (stall_acc_id),
      // ID Stage
      .decoded_instr_i       (issue_entry_id_issue),
      .decoded_instr_valid_i (issue_entry_valid_id_issue),
      .is_ctrl_flow_i        (is_ctrl_fow_id_issue),
      .decoded_instr_ack_o   (issue_instr_issue_id),
      // Functional Units
      .rs1_forwarding_o      (rs1_forwarding_id_ex),
      .rs2_forwarding_o      (rs2_forwarding_id_ex),
      .fu_data_o             (fu_data_id_ex),
      .pc_o                  (pc_id_ex),
      .is_compressed_instr_o (is_compressed_instr_id_ex),
      // fixed latency unit ready
      .flu_ready_i           (flu_ready_ex_id),
      // ALU
      .alu_valid_o           (alu_valid_id_ex),
      // Branches and Jumps
      .branch_valid_o        (branch_valid_id_ex),            // branch is valid
      .branch_predict_o      (branch_predict_id_ex),          // branch predict to ex
      .resolve_branch_i      (resolve_branch_ex_id),          // in order to resolve the branch
      // LSU
      .lsu_ready_i           (lsu_ready_ex_id),
      .lsu_valid_o           (lsu_valid_id_ex),
      // Multiplier
      .mult_valid_o          (mult_valid_id_ex),
      // FPU
      .fpu_ready_i           (fpu_ready_ex_id),
      .fpu_valid_o           (fpu_valid_id_ex),
      .fpu_fmt_o             (fpu_fmt_id_ex),
      .fpu_rm_o              (fpu_rm_id_ex),
      // CSR
      .csr_valid_o           (csr_valid_id_ex),
      // CVXIF
      .x_issue_valid_o       (x_issue_valid_id_ex),
      .x_issue_ready_i       (x_issue_ready_ex_id),
      .x_off_instr_o         (x_off_instr_id_ex),
      // Accelerator
      .issue_instr_o         (issue_instr_id_acc),
      .issue_instr_hs_o      (issue_instr_hs_id_acc),
      // Commit
      .resolved_branch_i     (resolved_branch),
      .trans_id_i            (trans_id_ex_id),
      .wbdata_i              (wbdata_ex_id),
      .ex_ex_i               (ex_ex_ex_id),
      .wt_valid_i            (wt_valid_ex_id),
      .x_we_i                (x_we_ex_id),

      .waddr_i            (waddr_commit_id),
      .wdata_i            (wdata_commit_id),
      .we_gpr_i           (we_gpr_commit_id),
      .we_fpr_i           (we_fpr_commit_id),
      .commit_instr_o     (commit_instr_id_commit),
      .commit_ack_i       (commit_ack),
      // Performance Counters
      .stall_issue_o      (stall_issue),
      //RVFI
      .lsu_addr_i         (lsu_addr),
      .lsu_rmask_i        (lsu_rmask),
      .lsu_wmask_i        (lsu_wmask),
      .lsu_addr_trans_id_i(lsu_addr_trans_id),
      .*
  );

  // ---------
  // EX
  // ---------
  ex_stage #(
      .CVA6Cfg   (CVA6ExtendCfg),
      .ASID_WIDTH(ASID_WIDTH)
  ) ex_stage_i (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .debug_mode_i         (debug_mode),
      .flush_i              (flush_ctrl_ex),
      .rs1_forwarding_i     (rs1_forwarding_id_ex),
      .rs2_forwarding_i     (rs2_forwarding_id_ex),
      .fu_data_i            (fu_data_id_ex),
      .pc_i                 (pc_id_ex),
      .is_compressed_instr_i(is_compressed_instr_id_ex),
      // fixed latency units
      .flu_result_o         (flu_result_ex_id),
      .flu_trans_id_o       (flu_trans_id_ex_id),
      .flu_valid_o          (flu_valid_ex_id),
      .flu_exception_o      (flu_exception_ex_id),
      .flu_ready_o          (flu_ready_ex_id),
      // ALU
      .alu_valid_i          (alu_valid_id_ex),
      // Branches and Jumps
      .branch_valid_i       (branch_valid_id_ex),
      .branch_predict_i     (branch_predict_id_ex),       // branch predict to ex
      .resolved_branch_o    (resolved_branch),
      .resolve_branch_o     (resolve_branch_ex_id),
      // CSR
      .csr_valid_i          (csr_valid_id_ex),
      .csr_addr_o           (csr_addr_ex_csr),
      .csr_commit_i         (csr_commit_commit_ex),       // from commit
      // MULT
      .mult_valid_i         (mult_valid_id_ex),
      // LSU
      .lsu_ready_o          (lsu_ready_ex_id),
      .lsu_valid_i          (lsu_valid_id_ex),

      .load_result_o   (load_result_ex_id),
      .load_trans_id_o (load_trans_id_ex_id),
      .load_valid_o    (load_valid_ex_id),
      .load_exception_o(load_exception_ex_id),

      .store_result_o   (store_result_ex_id),
      .store_trans_id_o (store_trans_id_ex_id),
      .store_valid_o    (store_valid_ex_id),
      .store_exception_o(store_exception_ex_id),

      .lsu_commit_i           (lsu_commit_commit_ex),          // from commit
      .lsu_commit_ready_o     (lsu_commit_ready_ex_commit),    // to commit
      .commit_tran_id_i       (lsu_commit_trans_id),           // from commit
      .stall_st_pending_i     (stall_st_pending_ex),
      .no_st_pending_o        (no_st_pending_ex),
      // FPU
      .fpu_ready_o            (fpu_ready_ex_id),
      .fpu_valid_i            (fpu_valid_id_ex),
      .fpu_fmt_i              (fpu_fmt_id_ex),
      .fpu_rm_i               (fpu_rm_id_ex),
      .fpu_frm_i              (frm_csr_id_issue_ex),
      .fpu_prec_i             (fprec_csr_ex),
      .fpu_trans_id_o         (fpu_trans_id_ex_id),
      .fpu_result_o           (fpu_result_ex_id),
      .fpu_valid_o            (fpu_valid_ex_id),
      .fpu_exception_o        (fpu_exception_ex_id),
      .amo_valid_commit_i     (amo_valid_commit),
      .amo_req_o              (amo_req),
      .amo_resp_i             (amo_resp),
      // CoreV-X-Interface
      .x_valid_i              (x_issue_valid_id_ex),
      .x_ready_o              (x_issue_ready_ex_id),
      .x_off_instr_i          (x_off_instr_id_ex),
      .x_trans_id_o           (x_trans_id_ex_id),
      .x_exception_o          (x_exception_ex_id),
      .x_result_o             (x_result_ex_id),
      .x_valid_o              (x_valid_ex_id),
      .x_we_o                 (x_we_ex_id),
      .cvxif_req_o            (cvxif_req),
      .cvxif_resp_i           (cvxif_resp),
      // Accelerator
      .acc_valid_i            (acc_valid_acc_ex),
      // Performance counters
      .itlb_miss_o            (itlb_miss_ex_perf),
      .dtlb_miss_o            (dtlb_miss_ex_perf),
      // Memory Management
      .enable_translation_i   (enable_translation_csr_ex),     // from CSR
      .en_ld_st_translation_i (en_ld_st_translation_csr_ex),
      .flush_tlb_i            (flush_tlb_ctrl_ex),
      .priv_lvl_i             (priv_lvl),                      // from CSR
      .ld_st_priv_lvl_i       (ld_st_priv_lvl_csr_ex),         // from CSR
      .sum_i                  (sum_csr_ex),                    // from CSR
      .mxr_i                  (mxr_csr_ex),                    // from CSR
      .satp_ppn_i             (satp_ppn_csr_ex),               // from CSR
      .asid_i                 (asid_csr_ex),                   // from CSR
      .icache_areq_i          (icache_areq_cache_ex),
      .icache_areq_o          (icache_areq_ex_cache),
      // DCACHE interfaces
      .dcache_req_ports_i     (dcache_req_ports_cache_ex),
      .dcache_req_ports_o     (dcache_req_ports_ex_cache),
      .dcache_wbuffer_empty_i (dcache_commit_wbuffer_empty),
      .dcache_wbuffer_not_ni_i(dcache_commit_wbuffer_not_ni),
      // PMP
      .pmpcfg_i               (pmpcfg),
      .pmpaddr_i              (pmpaddr),
      //RVFI
      .lsu_addr_o             (lsu_addr),
      .mem_paddr_o            (mem_paddr),
      .lsu_rmask_o            (lsu_rmask),
      .lsu_wmask_o            (lsu_wmask),
      .lsu_addr_trans_id_o    (lsu_addr_trans_id)
  );

  // ---------
  // Commit
  // ---------

  // we have to make sure that the whole write buffer path is empty before
  // used e.g. for fence instructions.
  assign no_st_pending_commit = no_st_pending_ex & dcache_commit_wbuffer_empty;

  commit_stage #(
      .CVA6Cfg(CVA6ExtendCfg)
  ) commit_stage_i (
      .clk_i,
      .rst_ni,
      .halt_i            (halt_ctrl),
      .flush_dcache_i    (dcache_flush_ctrl_cache),
      .exception_o       (ex_commit),
      .dirty_fp_state_o  (dirty_fp_state),
      .single_step_i     (single_step_csr_commit),
      .commit_instr_i    (commit_instr_id_commit),
      .commit_ack_o      (commit_ack),
      .no_st_pending_i   (no_st_pending_commit),
      .waddr_o           (waddr_commit_id),
      .wdata_o           (wdata_commit_id),
      .we_gpr_o          (we_gpr_commit_id),
      .we_fpr_o          (we_fpr_commit_id),
      .commit_lsu_o      (lsu_commit_commit_ex),
      .commit_lsu_ready_i(lsu_commit_ready_ex_commit),
      .commit_tran_id_o  (lsu_commit_trans_id),
      .amo_valid_commit_o(amo_valid_commit),
      .amo_resp_i        (amo_resp),
      .commit_csr_o      (csr_commit_commit_ex),
      .pc_o              (pc_commit),
      .csr_op_o          (csr_op_commit_csr),
      .csr_wdata_o       (csr_wdata_commit_csr),
      .csr_rdata_i       (csr_rdata_csr_commit),
      .csr_write_fflags_o(csr_write_fflags_commit_cs),
      .csr_exception_i   (csr_exception_csr_commit),
      .fence_i_o         (fence_i_commit_controller),
      .fence_o           (fence_commit_controller),
      .sfence_vma_o      (sfence_vma_commit_controller),
      .flush_commit_o    (flush_commit),
      .*
  );

  // ---------
  // CSR
  // ---------
  csr_regfile #(
      .CVA6Cfg       (CVA6ExtendCfg),
      .AsidWidth     (ASID_WIDTH),
      .MHPMCounterNum(MHPMCounterNum)
  ) csr_regfile_i (
      .flush_o               (flush_csr_ctrl),
      .halt_csr_o            (halt_csr_ctrl),
      .commit_instr_i        (commit_instr_id_commit),
      .commit_ack_i          (commit_ack),
      .boot_addr_i           (boot_addr_i[riscv::VLEN-1:0]),
      .hart_id_i             (hart_id_i[riscv::XLEN-1:0]),
      .ex_i                  (ex_commit),
      .csr_op_i              (csr_op_commit_csr),
      .csr_write_fflags_i    (csr_write_fflags_commit_cs),
      .dirty_fp_state_i      (dirty_fp_state),
      .dirty_v_state_i       (dirty_v_state),
      .csr_addr_i            (csr_addr_ex_csr),
      .csr_wdata_i           (csr_wdata_commit_csr),
      .csr_rdata_o           (csr_rdata_csr_commit),
      .pc_i                  (pc_commit),
      .csr_exception_o       (csr_exception_csr_commit),
      .epc_o                 (epc_commit_pcgen),
      .eret_o                (eret),
      .set_debug_pc_o        (set_debug_pc),
      .trap_vector_base_o    (trap_vector_base_commit_pcgen),
      .priv_lvl_o            (priv_lvl),
      .acc_fflags_ex_i       (acc_resp_fflags),
      .acc_fflags_ex_valid_i (acc_resp_fflags_valid),
      .fs_o                  (fs),
      .fflags_o              (fflags_csr_commit),
      .frm_o                 (frm_csr_id_issue_ex),
      .fprec_o               (fprec_csr_ex),
      .vs_o                  (vs),
      .irq_ctrl_o            (irq_ctrl_csr_id),
      .ld_st_priv_lvl_o      (ld_st_priv_lvl_csr_ex),
      .en_translation_o      (enable_translation_csr_ex),
      .en_ld_st_translation_o(en_ld_st_translation_csr_ex),
      .sum_o                 (sum_csr_ex),
      .mxr_o                 (mxr_csr_ex),
      .satp_ppn_o            (satp_ppn_csr_ex),
      .asid_o                (asid_csr_ex),
      .tvm_o                 (tvm_csr_id),
      .tw_o                  (tw_csr_id),
      .tsr_o                 (tsr_csr_id),
      .debug_mode_o          (debug_mode),
      .single_step_o         (single_step_csr_commit),
      .dcache_en_o           (dcache_en_csr_nbdcache),
      .icache_en_o           (icache_en_csr),
      .acc_cons_en_o         (acc_cons_en_csr),
      .perf_addr_o           (addr_csr_perf),
      .perf_data_o           (data_csr_perf),
      .perf_data_i           (data_perf_csr),
      .perf_we_o             (we_csr_perf),
      .pmpcfg_o              (pmpcfg),
      .pmpaddr_o             (pmpaddr),
      .mcountinhibit_o       (mcountinhibit_csr_perf),
      .debug_req_i,
      .ipi_i,
      .irq_i,
      .time_irq_i,
      .*
  );

  // ------------------------
  // Performance Counters
  // ------------------------
  if (PERF_COUNTER_EN) begin : gen_perf_counter
    perf_counters #(
        .CVA6Cfg (CVA6ExtendCfg),
        .NumPorts(NumPorts)
    ) perf_counters_i (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .debug_mode_i  (debug_mode),
        .addr_i        (addr_csr_perf),
        .we_i          (we_csr_perf),
        .data_i        (data_csr_perf),
        .data_o        (data_perf_csr),
        .commit_instr_i(commit_instr_id_commit),
        .commit_ack_i  (commit_ack),

        .l1_icache_miss_i   (icache_miss_cache_perf),
        .l1_dcache_miss_i   (dcache_miss_cache_perf),
        .itlb_miss_i        (itlb_miss_ex_perf),
        .dtlb_miss_i        (dtlb_miss_ex_perf),
        .sb_full_i          (sb_full),
        .if_empty_i         (~fetch_valid_if_id),
        .ex_i               (ex_commit),
        .eret_i             (eret),
        .resolved_branch_i  (resolved_branch),
        .branch_exceptions_i(flu_exception_ex_id),
        .l1_icache_access_i (icache_dreq_if_cache),
        .l1_dcache_access_i (dcache_req_ports_ex_cache),
        .miss_vld_bits_i    (miss_vld_bits),
        .i_tlb_flush_i      (flush_tlb_ctrl_ex),
        .stall_issue_i      (stall_issue),
        .mcountinhibit_i    (mcountinhibit_csr_perf)
    );
  end : gen_perf_counter
  else begin : gen_no_perf_counter
    assign data_perf_csr = '0;
  end : gen_no_perf_counter

  // ------------
  // Controller
  // ------------
  controller #(
      .CVA6Cfg(CVA6ExtendCfg)
  ) controller_i (
      // flush ports
      .set_pc_commit_o       (set_pc_ctrl_pcgen),
      .flush_unissued_instr_o(flush_unissued_instr_ctrl_id),
      .flush_if_o            (flush_ctrl_if),
      .flush_id_o            (flush_ctrl_id),
      .flush_ex_o            (flush_ctrl_ex),
      .flush_bp_o            (flush_ctrl_bp),
      .flush_tlb_o           (flush_tlb_ctrl_ex),
      .flush_dcache_o        (dcache_flush_ctrl_cache),
      .flush_dcache_ack_i    (dcache_flush_ack_cache_ctrl),

      .halt_csr_i       (halt_csr_ctrl),
      .halt_acc_i       (halt_acc_ctrl),
      .halt_o           (halt_ctrl),
      // control ports
      .eret_i           (eret),
      .ex_valid_i       (ex_commit.valid),
      .set_debug_pc_i   (set_debug_pc),
      .flush_csr_i      (flush_csr_ctrl),
      .resolved_branch_i(resolved_branch),
      .fence_i_i        (fence_i_commit_controller),
      .fence_i          (fence_commit_controller),
      .sfence_vma_i     (sfence_vma_commit_controller),
      .flush_commit_i   (flush_commit),
      .flush_acc_i      (flush_acc),

      .flush_icache_o(icache_flush_ctrl_cache),
      .*
  );

  // -------------------
  // Cache Subsystem
  // -------------------

  // Acc dispatcher and store buffer share a dcache request port.
  // Store buffer always has priority access over acc dipsatcher.
  dcache_req_i_t [NumPorts-1:0] dcache_req_to_cache;
  dcache_req_o_t [NumPorts-1:0] dcache_req_from_cache;

  // D$ request
  assign dcache_req_to_cache[0] = dcache_req_ports_ex_cache[0];
  assign dcache_req_to_cache[1] = dcache_req_ports_ex_cache[1];
  assign dcache_req_to_cache[2] = dcache_req_ports_acc_cache[0];
  assign dcache_req_to_cache[3] = dcache_req_ports_ex_cache[2].data_req ? dcache_req_ports_ex_cache [2] :
                                                                          dcache_req_ports_acc_cache[1];

  // D$ response
  assign dcache_req_ports_cache_ex[0] = dcache_req_from_cache[0];
  assign dcache_req_ports_cache_ex[1] = dcache_req_from_cache[1];
  assign dcache_req_ports_cache_acc[0] = dcache_req_from_cache[2];
  always_comb begin : gen_dcache_req_store_data_gnt
    dcache_req_ports_cache_ex[2]  = dcache_req_from_cache[3];
    dcache_req_ports_cache_acc[1] = dcache_req_from_cache[3];

    // Set gnt signal
    dcache_req_ports_cache_ex[2].data_gnt &= dcache_req_ports_ex_cache[2].data_req;
    dcache_req_ports_cache_acc[1].data_gnt &= !dcache_req_ports_ex_cache[2].data_req;
  end

  if (DCACHE_TYPE == int'(config_pkg::WT)) begin : gen_cache_wt
    // this is a cache subsystem that is compatible with OpenPiton
    wt_cache_subsystem #(
        .CVA6Cfg   (CVA6ExtendCfg),
        .NumPorts  (NumPorts),
        .noc_req_t (noc_req_t),
        .noc_resp_t(noc_resp_t)
    ) i_cache_subsystem (
        // to D$
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        // I$
        .icache_en_i       (icache_en_csr),
        .icache_flush_i    (icache_flush_ctrl_cache),
        .icache_miss_o     (icache_miss_cache_perf),
        .icache_areq_i     (icache_areq_ex_cache),
        .icache_areq_o     (icache_areq_cache_ex),
        .icache_dreq_i     (icache_dreq_if_cache),
        .icache_dreq_o     (icache_dreq_cache_if),
        // D$
        .dcache_enable_i   (dcache_en_csr_nbdcache),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        // to commit stage
        .dcache_amo_req_i  (amo_req),
        .dcache_amo_resp_o (amo_resp),
        // from PTW, Load Unit  and Store Unit
        .dcache_miss_o     (dcache_miss_cache_perf),
        .miss_vld_bits_o   (miss_vld_bits),
        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),
        // write buffer status
        .wbuffer_empty_o   (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o  (dcache_commit_wbuffer_not_ni),
        // memory side
        .noc_req_o         (noc_req_o),
        .noc_resp_i        (noc_resp_i),
        .inval_addr_i      (inval_addr),
        .inval_valid_i     (inval_valid),
        .inval_ready_o     (inval_ready)
    );
  end else if (DCACHE_TYPE == int'(config_pkg::HPDCACHE)) begin : gen_cache_hpd
    cva6_hpdcache_subsystem #(
        .CVA6Cfg   (CVA6ExtendCfg),
        .NumPorts  (NumPorts),
        .noc_req_t (noc_req_t),
        .noc_resp_t(noc_resp_t),
        .cmo_req_t (logic  /*FIXME*/),
        .cmo_rsp_t (logic  /*FIXME*/)
    ) i_cache_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .icache_en_i   (icache_en_csr),
        .icache_flush_i(icache_flush_ctrl_cache),
        .icache_miss_o (icache_miss_cache_perf),
        .icache_areq_i (icache_areq_ex_cache),
        .icache_areq_o (icache_areq_cache_ex),
        .icache_dreq_i (icache_dreq_if_cache),
        .icache_dreq_o (icache_dreq_cache_if),

        .dcache_enable_i   (dcache_en_csr_nbdcache),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        .dcache_miss_o     (dcache_miss_cache_perf),

        .dcache_amo_req_i (amo_req),
        .dcache_amo_resp_o(amo_resp),

        .dcache_cmo_req_i ('0  /*FIXME*/),
        .dcache_cmo_resp_o(  /*FIXME*/),

        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),

        .wbuffer_empty_o (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o(dcache_commit_wbuffer_not_ni),

        .hwpf_base_set_i    ('0  /*FIXME*/),
        .hwpf_base_i        ('0  /*FIXME*/),
        .hwpf_base_o        (  /*FIXME*/),
        .hwpf_param_set_i   ('0  /*FIXME*/),
        .hwpf_param_i       ('0  /*FIXME*/),
        .hwpf_param_o       (  /*FIXME*/),
        .hwpf_throttle_set_i('0  /*FIXME*/),
        .hwpf_throttle_i    ('0  /*FIXME*/),
        .hwpf_throttle_o    (  /*FIXME*/),
        .hwpf_status_o      (  /*FIXME*/),

        .noc_req_o (noc_req_o),
        .noc_resp_i(noc_resp_i)
    );
    assign inval_ready = 1'b1;
  end else begin : gen_cache_wb
    std_cache_subsystem #(
        // note: this only works with one cacheable region
        // not as important since this cache subsystem is about to be
        // deprecated
        .CVA6Cfg      (CVA6ExtendCfg),
        .NumPorts     (NumPorts),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t (axi_w_chan_t),
        .axi_req_t    (noc_req_t),
        .axi_rsp_t    (noc_resp_t)
    ) i_cache_subsystem (
        // to D$
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        .priv_lvl_i        (priv_lvl),
        // I$
        .icache_en_i       (icache_en_csr),
        .icache_flush_i    (icache_flush_ctrl_cache),
        .icache_miss_o     (icache_miss_cache_perf),
        .icache_areq_i     (icache_areq_ex_cache),
        .icache_areq_o     (icache_areq_cache_ex),
        .icache_dreq_i     (icache_dreq_if_cache),
        .icache_dreq_o     (icache_dreq_cache_if),
        // D$
        .dcache_enable_i   (dcache_en_csr_nbdcache),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        // to commit stage
        .amo_req_i         (amo_req),
        .amo_resp_o        (amo_resp),
        .dcache_miss_o     (dcache_miss_cache_perf),
        // this is statically set to 1 as the std_cache does not have a wbuffer
        .wbuffer_empty_o   (dcache_commit_wbuffer_empty),
        // from PTW, Load Unit  and Store Unit
        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),
        // memory side
        .axi_req_o         (noc_req_o),
        .axi_resp_i        (noc_resp_i)
    );
    assign dcache_commit_wbuffer_not_ni = 1'b1;
    assign inval_ready                  = 1'b1;
  end

  // ----------------
  // Accelerator
  // ----------------

  if (CVA6ExtendCfg.EnableAccelerator) begin : gen_accelerator
    acc_dispatcher #(
        .CVA6Cfg   (CVA6ExtendCfg),
        .acc_cfg_t (acc_cfg_t),
        .AccCfg    (AccCfg),
        .acc_req_t (cvxif_req_t),
        .acc_resp_t(cvxif_resp_t)
    ) i_acc_dispatcher (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),
        .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
        .flush_ex_i            (flush_ctrl_ex),
        .flush_pipeline_o      (flush_acc),
        .acc_cons_en_i         (acc_cons_en_csr),
        .acc_fflags_valid_o    (acc_resp_fflags_valid),
        .acc_fflags_o          (acc_resp_fflags),
        .fcsr_frm_i            (frm_csr_id_issue_ex),
        .dirty_v_state_o       (dirty_v_state),
        .issue_instr_i         (issue_instr_id_acc),
        .issue_instr_hs_i      (issue_instr_hs_id_acc),
        .issue_stall_o         (stall_acc_id),
        .fu_data_i             (fu_data_id_ex),
        .commit_instr_i        (commit_instr_id_commit),
        .commit_st_barrier_i   (fence_i_commit_controller | fence_commit_controller),
        .acc_trans_id_o        (acc_trans_id_ex_id),
        .acc_result_o          (acc_result_ex_id),
        .acc_valid_o           (acc_valid_ex_id),
        .acc_exception_o       (acc_exception_ex_id),
        .acc_valid_ex_o        (acc_valid_acc_ex),
        .commit_ack_i          (commit_ack),
        .acc_stall_st_pending_o(stall_st_pending_ex),
        .acc_no_st_pending_i   (no_st_pending_commit),
        .dcache_req_ports_i    (dcache_req_ports_ex_cache),
        .ctrl_halt_o           (halt_acc_ctrl),
        .acc_dcache_req_ports_o(dcache_req_ports_acc_cache),
        .acc_dcache_req_ports_i(dcache_req_ports_cache_acc),
        .inval_ready_i         (inval_ready),
        .inval_valid_o         (inval_valid),
        .inval_addr_o          (inval_addr),
        .acc_req_o             (cvxif_req),
        .acc_resp_i            (cvxif_resp)
    );
  end : gen_accelerator
  else if (CVA6Cfg.CvxifEn) begin : gen_coprocessor
		in_pipeline_coprocessor i_in_pipeline_coprocessor (
		  .clk_i                ( clk_i                          ),
		  .rst_ni               ( rst_ni                         ),
		  .cvxif_req_i          ( cvxif_req                      ),
		  .cvxif_resp_o         ( cvxif_resp                     )
		);
  end
  else begin : gen_no_accelerator
    assign acc_trans_id_ex_id         = '0;
    assign acc_result_ex_id           = '0;
    assign acc_valid_ex_id            = '0;
    assign acc_exception_ex_id        = '0;
    assign acc_resp_fflags            = '0;
    assign acc_resp_fflags_valid      = '0;
    assign stall_acc_id               = '0;
    assign dirty_v_state              = '0;
    assign acc_valid_acc_ex           = '0;
    assign halt_acc_ctrl              = '0;
    assign stall_st_pending_ex        = '0;
    assign flush_acc                  = '0;
		assign cvxif_resp									= '{default: 0};

    // D$ connection is unused
    assign dcache_req_ports_acc_cache = '0;

    // No invalidation interface
    assign inval_valid                = '0;
    assign inval_addr                 = '0;
  end : gen_no_accelerator


  // -------------------
  // Parameter Check
  // -------------------
`ifndef VERILATOR
  initial config_pkg::check_cfg(CVA6Cfg);
`endif

  // -------------------
  // Instruction Tracer
  // -------------------

`ifdef PITON_ARIANE
  localparam PC_QUEUE_DEPTH = 16;

  logic                                                    piton_pc_vld;
  logic [                riscv::VLEN-1:0]                  piton_pc;
  logic [CVA6ExtendCfg.NrCommitPorts-1:0][riscv::VLEN-1:0] pc_data;
  logic [CVA6ExtendCfg.NrCommitPorts-1:0] pc_pop, pc_empty;

  for (genvar i = 0; i < CVA6ExtendCfg.NrCommitPorts; i++) begin : gen_pc_fifo
    fifo_v3 #(
        .DATA_WIDTH(64),
        .DEPTH(PC_QUEUE_DEPTH)
    ) i_pc_fifo (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   ('0),
        .testmode_i('0),
        .full_o    (),
        .empty_o   (pc_empty[i]),
        .usage_o   (),
        .data_i    (commit_instr_id_commit[i].pc),
        .push_i    (commit_ack[i] & ~commit_instr_id_commit[i].ex.valid),
        .data_o    (pc_data[i]),
        .pop_i     (pc_pop[i])
    );
  end

  rr_arb_tree #(
      .NumIn(CVA6ExtendCfg.NrCommitPorts),
      .DataWidth(64)
  ) i_rr_arb_tree (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .flush_i('0),
      .rr_i   ('0),
      .req_i  (~pc_empty),
      .gnt_o  (pc_pop),
      .data_i (pc_data),
      .gnt_i  (piton_pc_vld),
      .req_o  (piton_pc_vld),
      .data_o (piton_pc),
      .idx_o  ()
  );
`endif  // PITON_ARIANE



  if (IsRVFI) begin
    always_comb begin
      for (int i = 0; i < CVA6ExtendCfg.NrCommitPorts; i++) begin
        logic exception;
        exception = commit_instr_id_commit[i].valid && ex_commit.valid;
        rvfi_o[i].valid    = (commit_ack[i] && !ex_commit.valid) ||
          (exception && (ex_commit.cause == riscv::ENV_CALL_MMODE ||
                    ex_commit.cause == riscv::ENV_CALL_SMODE ||
                    ex_commit.cause == riscv::ENV_CALL_UMODE));
        rvfi_o[i].insn = ex_commit.valid ? ex_commit.tval[31:0] : commit_instr_id_commit[i].ex.tval[31:0];
        // when trap, the instruction is not executed
        rvfi_o[i].trap = exception;
        rvfi_o[i].cause = ex_commit.cause;
        rvfi_o[i].mode = (CVA6Cfg.DebugEn && debug_mode) ? 2'b10 : priv_lvl;
        rvfi_o[i].ixl = riscv::XLEN == 64 ? 2 : 1;
        rvfi_o[i].rs1_addr = commit_instr_id_commit[i].rs1[4:0];
        rvfi_o[i].rs2_addr = commit_instr_id_commit[i].rs2[4:0];
        rvfi_o[i].rd_addr = commit_instr_id_commit[i].rd[4:0];
        rvfi_o[i].rd_wdata =
            (CVA6ExtendCfg.FpPresent && ariane_pkg::is_rd_fpr(commit_instr_id_commit[i].op)) ?
            commit_instr_id_commit[i].result : wdata_commit_id[i];
        rvfi_o[i].pc_rdata = commit_instr_id_commit[i].pc;

        rvfi_o[i].mem_addr = commit_instr_id_commit[i].lsu_addr;
        // So far, only write paddr is reported. TODO: read paddr
        rvfi_o[i].mem_paddr = mem_paddr;
        rvfi_o[i].mem_wmask = commit_instr_id_commit[i].lsu_wmask;
        rvfi_o[i].mem_wdata = commit_instr_id_commit[i].lsu_wdata;
        rvfi_o[i].mem_rmask = commit_instr_id_commit[i].lsu_rmask;
        rvfi_o[i].mem_rdata = commit_instr_id_commit[i].result;
        rvfi_o[i].rs1_rdata = commit_instr_id_commit[i].rs1_rdata;
        rvfi_o[i].rs2_rdata = commit_instr_id_commit[i].rs2_rdata;

      end
    end
  end

endmodule  // ariane
