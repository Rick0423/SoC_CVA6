///////////////////////////////////////////////////////////////////////////////
// Description:  RTL Source Filelist
// Author:       Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
// Acknowledge:  Renati Tuerhong [Peking University]
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
//Not working Filelist , Only for code save
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Variable {SRC_DIR} is defined in config/global_config.tcl,
// default ${SRC_DIR} == src/
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Include && Package
///////////////////////////////////////////////////////////////////////////////

+incdir+${SRC_DIR}/misc/include/
+incdir+${SRC_DIR}/soc_axi/include/

// WARNING: ORDER is important !!!
${SRC_DIR}/cpu_cva6/include/config_pkg.sv
${SRC_DIR}/cpu_cva6/include/cv64a6_config_pkg.sv
${SRC_DIR}/cpu_cva6/include/riscv_pkg.sv
${SRC_DIR}/cpu_cva6/include/ariane_pkg.sv
${SRC_DIR}/cpu_cva6/include/wt_cache_pkg.sv
${SRC_DIR}/cpu_cva6/include/std_cache_pkg.sv
${SRC_DIR}/cpu_cva6/include/instr_tracer_pkg.sv
${SRC_DIR}/cpu_cva6/include/fpnew_pkg.sv
${SRC_DIR}/cpu_cva6/include/acc_pkg.sv
${SRC_DIR}/cpu_cva6/include/cvxif_pkg.sv
${SRC_DIR}/cpu_cva6/include/cvxif_instr_pkg.sv
${SRC_DIR}/soc_pkg.sv
${SRC_DIR}/soc_axi/axi_bus/include/axi_pkg.sv
${SRC_DIR}/soc_axi/axi_bus/include/ariane_axi_pkg.sv
${SRC_DIR}/soc_axi/axi_bus/include/ariane_axi_soc_pkg.sv
${SRC_DIR}/soc_axi/axi_bus/include/axi_intf.sv
${SRC_DIR}/soc_axi/reg_bus/reg_intf.sv
${SRC_DIR}/soc_axi/riscv-dbg/dm_pkg.sv
${SRC_DIR}/misc/cf_math_pkg.sv


///////////////////////////////////////////////////////////////////////////////
// Testbench
///////////////////////////////////////////////////////////////////////////////

${SRC_DIR}/../sim/soc_tb.sv
${SRC_DIR}/../sim/s27kl0642.v


///////////////////////////////////////////////////////////////////////////////
// SoC
///////////////////////////////////////////////////////////////////////////////

${SRC_DIR}/soc_pad_wrapper.sv
${SRC_DIR}/soc.sv
${SRC_DIR}/soc_axi/peripheral.sv

// AXI Bus
${SRC_DIR}/soc_axi/axi_bus/axi_multicut.sv
${SRC_DIR}/soc_axi/axi_bus/axi_cut.sv
${SRC_DIR}/soc_axi/axi_bus/axi_join.sv
${SRC_DIR}/soc_axi/axi_bus/axi_delayer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_id_prepend.sv
${SRC_DIR}/soc_axi/axi_bus/axi_atop_filter.sv
${SRC_DIR}/soc_axi/axi_bus/axi_err_slv.sv
${SRC_DIR}/soc_axi/axi_bus/axi_mux.sv
${SRC_DIR}/soc_axi/axi_bus/axi_demux.sv
${SRC_DIR}/soc_axi/axi_bus/axi_xbar.sv
${SRC_DIR}/soc_axi/axi_bus/axi_fifo.sv
${SRC_DIR}/soc_axi/axi_bus/axi_dw_converter.sv
${SRC_DIR}/soc_axi/axi_bus/axi_dw_downsizer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_dw_upsizer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_lite_interface.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_ar_buffer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_aw_buffer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_b_buffer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_r_buffer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_w_buffer.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_single_slice.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_slice.sv
${SRC_DIR}/soc_axi/axi_bus/axi_slice/axi_slice_wrap.sv

// Bus Converter
${SRC_DIR}/soc_axi/bus_converter/axi2mem.sv
${SRC_DIR}/soc_axi/bus_converter/axi2mem_multi_cycle_read.sv
${SRC_DIR}/soc_axi/bus_converter/apb_to_reg.sv
${SRC_DIR}/soc_axi/bus_converter/axi2apb_64_32.sv
${SRC_DIR}/soc_axi/bus_converter/axi_to_axi_lite.sv
${SRC_DIR}/soc_axi/bus_converter/axi_to_reg.sv
${SRC_DIR}/soc_axi/bus_converter/axi_lite_to_reg.sv

// RISC-V Debug Module
${SRC_DIR}/soc_axi/riscv-dbg/dm_csrs.sv
${SRC_DIR}/soc_axi/riscv-dbg/dmi_cdc.sv
${SRC_DIR}/soc_axi/riscv-dbg/dmi_jtag.sv
${SRC_DIR}/soc_axi/riscv-dbg/dmi_jtag_tap.sv
${SRC_DIR}/soc_axi/riscv-dbg/dm_mem.sv
${SRC_DIR}/soc_axi/riscv-dbg/dm_sba.sv
${SRC_DIR}/soc_axi/riscv-dbg/dm_top.sv
${SRC_DIR}/soc_axi/riscv-dbg/debug_rom.sv

// Core-local Interrupt Controller
${SRC_DIR}/soc_axi/clint.sv

// BootROM
${SRC_DIR}/soc_axi/bootrom.sv

// Main Memory
${SRC_DIR}/soc_axi/main_memory/main_memory_wrapper.sv

// Platform-Level Interrupt Controller
${SRC_DIR}/soc_axi/rv_plic/plic_regmap.sv
${SRC_DIR}/soc_axi/rv_plic/rv_plic_gateway.sv
${SRC_DIR}/soc_axi/rv_plic/rv_plic_target.sv
${SRC_DIR}/soc_axi/rv_plic/plic_top.sv

// Timer
${SRC_DIR}/soc_axi/apb_timer/apb_timer.sv
${SRC_DIR}/soc_axi/apb_timer/timer.sv

// UART
${SRC_DIR}/soc_axi/apb_uart/apb_uart.sv
${SRC_DIR}/soc_axi/apb_uart/slib_clock_div.sv
${SRC_DIR}/soc_axi/apb_uart/slib_counter.sv
${SRC_DIR}/soc_axi/apb_uart/slib_edge_detect.sv
${SRC_DIR}/soc_axi/apb_uart/slib_fifo.sv
${SRC_DIR}/soc_axi/apb_uart/slib_input_filter.sv
${SRC_DIR}/soc_axi/apb_uart/slib_input_sync.sv
${SRC_DIR}/soc_axi/apb_uart/slib_mv_filter.sv
${SRC_DIR}/soc_axi/apb_uart/uart_baudgen.sv
${SRC_DIR}/soc_axi/apb_uart/uart_interrupt.sv
${SRC_DIR}/soc_axi/apb_uart/uart_receiver.sv
${SRC_DIR}/soc_axi/apb_uart/uart_transmitter.sv

// Clk
${SRC_DIR}/soc_axi/clk/DCO.v
${SRC_DIR}/soc_axi/clk/DCO_regs.sv
${SRC_DIR}/soc_axi/clk/PLL_regs.sv

// Common Cells
${SRC_DIR}/misc/rstgen.sv
${SRC_DIR}/misc/rstgen_bypass.sv
${SRC_DIR}/misc/addr_decode.sv
${SRC_DIR}/misc/stream_register.sv
${SRC_DIR}/misc/stream_fifo.sv
${SRC_DIR}/misc/cdc_2phase.sv
${SRC_DIR}/misc/cdc_fifo_2phase.sv
${SRC_DIR}/misc/cdc_fifo_gray.sv
${SRC_DIR}/misc/binary_to_gray.sv
${SRC_DIR}/misc/gray_to_binary.sv
${SRC_DIR}/misc/spill_register_flushable.sv
${SRC_DIR}/misc/spill_register.sv
${SRC_DIR}/misc/fifo_v1.sv
${SRC_DIR}/misc/fifo_v2.sv
${SRC_DIR}/misc/stream_delay.sv
${SRC_DIR}/misc/lfsr_16bit.sv
${SRC_DIR}/misc/cluster_clk_cells.sv
${SRC_DIR}/misc/pulp_clk_cells.sv
${SRC_DIR}/misc/tc_clk.sv
${SRC_DIR}/misc/id_queue.sv
${SRC_DIR}/misc/onehot_to_bin.sv
${SRC_DIR}/misc/pad_functional.sv
${SRC_DIR}/misc/sync.sv


///////////////////////////////////////////////////////////////////////////////
// CVA6 CPU Core
///////////////////////////////////////////////////////////////////////////////

${SRC_DIR}/cpu_cva6/cva6.sv

// Floating Point Unit
${SRC_DIR}/cpu_cva6/fpu/fpnew_cast_multi.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_classifier.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_divsqrt_multi.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_fma_multi.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_fma.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_noncomp.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_opgroup_block.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_opgroup_fmt_slice.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_opgroup_multifmt_slice.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_rounding.sv
${SRC_DIR}/cpu_cva6/fpu/fpnew_top.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/defs_div_sqrt_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/control_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/div_sqrt_top_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/iteration_div_sqrt_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/norm_div_sqrt_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/nrbd_nrsc_mvp.sv
${SRC_DIR}/cpu_cva6/fpu/fpu_div_sqrt_mvp/preprocess_mvp.sv

// CVXIF
${SRC_DIR}/cpu_cva6/cvxif_fu.sv
${SRC_DIR}/cpu_cva6/cvxif_example/cvxif_example_coprocessor.sv
${SRC_DIR}/cpu_cva6/cvxif_example/instr_decoder.sv

// Common Cells
${SRC_DIR}/misc/fifo_v3.sv
${SRC_DIR}/misc/lfsr.sv
${SRC_DIR}/misc/lfsr_8bit.sv
${SRC_DIR}/misc/stream_arbiter.sv
${SRC_DIR}/misc/stream_arbiter_flushable.sv
${SRC_DIR}/misc/stream_mux.sv
${SRC_DIR}/misc/stream_demux.sv
${SRC_DIR}/misc/lzc.sv
${SRC_DIR}/misc/rr_arb_tree.sv
${SRC_DIR}/misc/shift_reg.sv
${SRC_DIR}/misc/unread.sv
${SRC_DIR}/misc/popcount.sv
${SRC_DIR}/misc/exp_backoff.sv
${SRC_DIR}/misc/counter.sv
${SRC_DIR}/misc/delta_counter.sv

// Top-level Source Files (not necessarily instantiated at the top of the cva6).
${SRC_DIR}/cpu_cva6/alu.sv
${SRC_DIR}/cpu_cva6/fpu_wrap.sv
${SRC_DIR}/cpu_cva6/branch_unit.sv
${SRC_DIR}/cpu_cva6/compressed_decoder.sv
${SRC_DIR}/cpu_cva6/controller.sv
${SRC_DIR}/cpu_cva6/csr_buffer.sv
${SRC_DIR}/cpu_cva6/csr_regfile.sv
${SRC_DIR}/cpu_cva6/decoder.sv
${SRC_DIR}/cpu_cva6/ex_stage.sv
${SRC_DIR}/cpu_cva6/instr_realign.sv
${SRC_DIR}/cpu_cva6/id_stage.sv
${SRC_DIR}/cpu_cva6/issue_read_operands.sv
${SRC_DIR}/cpu_cva6/issue_stage.sv
${SRC_DIR}/cpu_cva6/load_unit.sv
${SRC_DIR}/cpu_cva6/load_store_unit.sv
${SRC_DIR}/cpu_cva6/lsu_bypass.sv
${SRC_DIR}/cpu_cva6/mult.sv
${SRC_DIR}/cpu_cva6/multiplier.sv
${SRC_DIR}/cpu_cva6/serdiv.sv
${SRC_DIR}/cpu_cva6/perf_counters.sv
${SRC_DIR}/cpu_cva6/ariane_regfile_ff.sv
${SRC_DIR}/cpu_cva6/ariane_regfile_fpga.sv
${SRC_DIR}/cpu_cva6/scoreboard.sv
${SRC_DIR}/cpu_cva6/store_buffer.sv
${SRC_DIR}/cpu_cva6/amo_buffer.sv
${SRC_DIR}/cpu_cva6/store_unit.sv
${SRC_DIR}/cpu_cva6/commit_stage.sv
${SRC_DIR}/cpu_cva6/axi_shim.sv
${SRC_DIR}/cpu_cva6/cva6_accel_first_pass_decoder_stub.sv
${SRC_DIR}/cpu_cva6/acc_dispatcher.sv

// Frontend
${SRC_DIR}/cpu_cva6/frontend/btb.sv
${SRC_DIR}/cpu_cva6/frontend/bht.sv
${SRC_DIR}/cpu_cva6/frontend/ras.sv
${SRC_DIR}/cpu_cva6/frontend/instr_scan.sv
${SRC_DIR}/cpu_cva6/frontend/instr_queue.sv
${SRC_DIR}/cpu_cva6/frontend/frontend.sv

// Cache Subsystem
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_dcache_ctrl.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_dcache_mem.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_dcache_missunit.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_dcache_wbuffer.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_dcache.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/cva6_icache.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_cache_subsystem.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/wt_axi_adapter.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/tag_cmp.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/axi_adapter.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/miss_handler.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/cache_ctrl.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/cva6_icache_axi_wrapper.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/std_cache_subsystem.sv
${SRC_DIR}/cpu_cva6/cache_subsystem/std_nbdcache.sv

// Physical Memory Protection
${SRC_DIR}/cpu_cva6/pmp/src/pmp.sv
${SRC_DIR}/cpu_cva6/pmp/src/pmp_entry.sv

// Behavioral SRAM
${SRC_DIR}/misc/tc_sram_wrapper.sv
${SRC_DIR}/misc/tc_sram.sv
${SRC_DIR}/misc/sram.sv

// MMU Sv39
${SRC_DIR}/cpu_cva6/mmu_sv39/mmu.sv
${SRC_DIR}/cpu_cva6/mmu_sv39/ptw.sv
${SRC_DIR}/cpu_cva6/mmu_sv39/tlb.sv

// MMU Sv32
${SRC_DIR}/cpu_cva6/mmu_sv32/cva6_mmu_sv32.sv
${SRC_DIR}/cpu_cva6/mmu_sv32/cva6_ptw_sv32.sv
${SRC_DIR}/cpu_cva6/mmu_sv32/cva6_tlb_sv32.sv
${SRC_DIR}/cpu_cva6/mmu_sv32/cva6_shared_tlb_sv32.sv

///////////////////////////////////////////////////////////////////////////////
// Octree core 
///////////////////////////////////////////////////////////////////////////////

${SRC_DIR}/Octree/Control.sv
${SRC_DIR}/Octree/fifo_sync.sv
${SRC_DIR}/Octree/lod_compute.sv
${SRC_DIR}/Octree/Octree_wrapper.sv
${SRC_DIR}/Octree/Octree.sv
${SRC_DIR}/Octree/Searcher.sv
${SRC_DIR}/Octree/Updater.sv
${SRC_DIR}/Octree/sram_1024x64.sv


///////////////////////////////////////////////////////////////////////////////
// shield core 
///////////////////////////////////////////////////////////////////////////////
${SRC_DIR}/shield/anchor_shield.sv
${SRC_DIR}/shield/control.sv
${SRC_DIR}/shield/get0.sv
${SRC_DIR}/shield/oct_shield.sv
${SRC_DIR}/shield/register_level0.sv
${SRC_DIR}/shield/shield_top_wrapper.sv
${SRC_DIR}/shield/shield_top.sv
${SRC_DIR}/shield/sram_64x64.sv
${SRC_DIR}/shield/sram_128x64.sv