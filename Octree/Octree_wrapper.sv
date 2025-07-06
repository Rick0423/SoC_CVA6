//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-04
// Update Date:     2025-07-06
// Design Name:     Octree_wrapper
// Project Name:    VLSI-26 3DGS
// Description:     Connect Octree to SoC
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
module Octree_wrapper(
    input                               clk_i                      ,
    input                               rstn_i                     ,
    input                               mem_req_i                  ,
    input                               mem_write_en_i             ,
    input              [64/8-1: 0]      mem_byte_en_i              ,
    input                [64-1: 0]      mem_addr_i                 ,
    input                [64-1: 0]      mem_wdata_i                ,
    output               [64-1: 0]      mem_rdata_o                 
);

    ////////////////////////////////
    // CSR and Address Mapping
    ////////////////////////////////
    // CSR fields: pos_encode (14b), ctrl (2b), tree_num (4b), lod_param [0..4] (5x16b),
    //            local_sram_en (1b), in_out_sram_en (1b), op_done (2b output).
    // csr_mem[0]: {pos_encode(14b) ,ctrl (2b),tree_num (4b),local_sram_en (1b),in_out_sram_en (1b),...,lod_param[0](16b)}
    // csr_mem[1]: {lod_param[1] , lod_param[2] ,lod_param[3],lod_param[4] }
    localparam logic [64-1:0] CSR_MEM_0_ADDR     = 64'h6000_0000;
    localparam logic [64-1:0] CSR_MEM_1_ADDR     = 64'h6001_0000;
    localparam logic [64-1:0] CSR_CONTROL_ADDR   = 64'h600f_0000;
    localparam logic [64-1:0] LOCAL_SRAM_BASE_ADDR = 64'h6010_0000;
    localparam logic [64-1:0] LOCAL_SRAM_LENGTH    = 64'h0000_2000; // 8KB
    localparam logic [64-1:0] IN_OUT_SRAM_BASE_ADDR= 64'h6020_0000;
    localparam logic [64-1:0] IN_OUT_SRAM_LENGTH   = 64'h0000_2000; // 8KB


    // Internal CSR registers (drive by writes, read by bus)
    logic             [1:0][63: 0]      csr_mem                     ;
    logic     [3*4+$clog2(4)-1: 0]      csr_pos_encode              ;
    logic                [   1: 0]      csr_ctrl                    ;
    logic                [   3: 0]      csr_tree_num                ;
    logic                [   1: 0]      csr_op_done                 ;
    logic                               csr_local_sram_en           ;
    logic                               csr_in_out_sram_en          ;
    logic             [4:0][15: 0]      csr_lod_param               ;
    // in_out_sram_interface
    logic                               axi_in_out_SRAM_req_i       ;
    logic                               axi_in_out_SRAM_we_i        ;
    logic                [   9: 0]      axi_in_out_SRAM_addr_i      ;
    logic                [  63: 0]      axi_in_out_SRAM_wdata_i     ;
    logic                [  63: 0]      axi_in_out_SRAM_rdata_o     ;
    // local_sram_interface
    logic                               axi_local_SRAM_req_i        ;
    logic                               axi_local_SRAM_we_i         ;
    logic                [   9: 0]      axi_local_SRAM_addr_i       ;
    logic                [  63: 0]      axi_local_SRAM_wdata_i      ;
    logic                [  63: 0]      axi_local_SRAM_rdata_o      ;

    // Read data register and address-valid flags
    logic                [64-1: 0]      rdata_reg                   ;
    logic                               reg_addr_valid              ;

    // Convert byte-enable to bit-enable mask (64-bit wide)
    logic                [64-1: 0]      mem_bit_en                  ;
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            mem_bit_en[i*8 +: 8] = {8{mem_byte_en_i[i]}};
        end
    end

    ///////////////////////////////////////
    // CSR register read/write logic
    ///////////////////////////////////////
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            // Reset all CSR registers
            csr_mem          <= '0;
            rdata_reg        <= '0;
            reg_addr_valid   <= 1'b0;
        end else begin
            // Default: no valid CSR address accessed
            reg_addr_valid <= 1'b0;
            // Default read data pattern (if not matching any CSR)
            rdata_reg <= 64'hDEADBEEF_DEADBEEF;

            // Handle bus write
           if (mem_req_i & mem_write_en_i) begin
                case (mem_addr_i)
                    CSR_MEM_0_ADDR: begin
                            csr_mem[0]  <= mem_wdata_i & mem_bit_en;
                            reg_addr_valid     <= 1'b1;
                    end
                    CSR_MEM_1_ADDR: begin
                            csr_mem[1]  <= mem_wdata_i & mem_bit_en;
                            reg_addr_valid     <= 1'b1;
                    end 
                endcase
            end

            // Handle bus read
            else if (mem_req_i && !mem_write_en_i) begin
                case (mem_addr_i)
                    CSR_MEM_0_ADDR: begin
                            rdata_reg      <= csr_mem[0];
                            reg_addr_valid <= 1'b1;
                    end
                    CSR_MEM_1_ADDR: begin
                            rdata_reg      <= csr_mem[1];
                            reg_addr_valid <= 1'b1;
                    end
                    CSR_CONTROL_ADDR:begin
                            rdata_reg      <= {62'd0,csr_op_done};
                            reg_addr_valid <= 1'b1;    
                    end
                endcase
            end
        end
    end

    // csr_mem[0]: {pos_encode(14b) ,ctrl (2b),tree_num (4b),...,local_sram_en (1b),in_out_sram_en (1b),lod_param[0](16b)}
    // csr_mem[1]: {lod_param[1] , lod_param[2] ,lod_param[3],lod_param[4] }
    assign      csr_pos_encode       = csr_mem[0][63:50];
    assign      csr_ctrl             = csr_mem[0][49:48];
    assign      csr_tree_num         = csr_mem[0][47:44];
    assign      csr_local_sram_en    = csr_mem[0][17];
    assign      csr_in_out_sram_en   = csr_mem[0][16];
    assign      csr_lod_param[0]     = csr_mem[0][15:0];
    assign      csr_lod_param[1]     = csr_mem[1][63:48];
    assign      csr_lod_param[2]     = csr_mem[1][47:32];
    assign      csr_lod_param[3]     = csr_mem[1][31:16];
    assign      csr_lod_param[4]     = csr_mem[1][15:0];

    /////////////////////////////
    // SRAM interface crossbar
    /////////////////////////////
    // Default assignments
    logic [64-1:0] rdata_mem;
    logic         mem_addr_valid_d, mem_addr_valid_q;
    logic [64-1:0] rdata_addr_d, rdata_addr_q;
    logic         mem_req_q;
    logic [64-1:0] mem_rdata_q;
    logic         mem_rdata_valid_q;

    // Default outputs low
    always_comb begin
        // Default no SRAM request
        axi_local_SRAM_req_i        = 1'b0;
        axi_local_SRAM_we_i         = 1'b0;
        axi_local_SRAM_addr_i       = 10'b0;
        axi_local_SRAM_wdata_i      = 64'b0;

        axi_in_out_SRAM_req_i       = 1'b0;
        axi_in_out_SRAM_we_i        = 1'b0;
        axi_in_out_SRAM_addr_i      = 10'b0;
        axi_in_out_SRAM_wdata_i     = 64'b0;

        rdata_mem                   = 64'hDEADBEEF_DEADBEEF;
        mem_addr_valid_d            = 1'b0;

        if (mem_req_i) begin
            case (mem_addr_i[32-4-1:20]) // [27:20]
                LOCAL_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_local_SRAM_req_i   = 1'b1;
                        axi_local_SRAM_we_i    = mem_write_en_i;
                        axi_local_SRAM_addr_i  = mem_addr_i[12:3]; // 10-bit index for 8KB/8 bytes
                        axi_local_SRAM_wdata_i = mem_wdata_i;
                        mem_addr_valid_d       = 1'b1;
                        rdata_addr_d           = mem_addr_i;
                    end
                end
                IN_OUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_in_out_SRAM_req_i   = 1'b1;
                        axi_in_out_SRAM_we_i    = mem_write_en_i;
                        axi_in_out_SRAM_addr_i  = mem_addr_i[12:3];
                        axi_in_out_SRAM_wdata_i = mem_wdata_i;
                        mem_addr_valid_d        = 1'b1;
                        rdata_addr_d            = mem_addr_i;
                    end
                end
                default:begin
                    axi_local_SRAM_req_i        = 1'b0;
                    axi_local_SRAM_we_i         = 1'b0;
                    axi_local_SRAM_addr_i       = 10'b0;
                    axi_local_SRAM_wdata_i      = 64'b0;
                    axi_in_out_SRAM_req_i       = 1'b0;
                    axi_in_out_SRAM_we_i        = 1'b0;
                    axi_in_out_SRAM_addr_i      = 10'b0;
                    axi_in_out_SRAM_wdata_i     = 64'b0;
                    mem_addr_valid_d            = 1'b0;
                end
            endcase
        end

        // Read from the SRAM that was addressed one cycle ago
        if (mem_addr_valid_q) begin
            case (rdata_addr_q[32-4-1:20])
                LOCAL_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = axi_local_SRAM_rdata_o;
                    end
                end
                IN_OUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = axi_in_out_SRAM_rdata_o;
                    end
                end
                default:begin
                    rdata_mem                   = 64'hDEADBEEF_DEADBEEF;
                end
            endcase
        end
    end

    // Pipeline address valid and captured address
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            mem_addr_valid_q <= 1'b0;
            rdata_addr_q     <= '0;
        end else begin
            mem_addr_valid_q <= mem_addr_valid_d;
            rdata_addr_q     <= rdata_addr_d;
        end
    end

    // Handle final read-data output (from registers or SRAM)
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            mem_req_q         <= 1'b0;
            mem_rdata_valid_q <= 1'b0;
            mem_rdata_q       <= '0;
        end else begin
            mem_req_q <= mem_req_i;
            if (mem_req_q) begin
                // Combine register read data or SRAM read data
                mem_rdata_valid_q <= 1'b1;
                mem_rdata_q <= (rdata_reg   & {64{reg_addr_valid}}) |
                               (rdata_mem   & {64{mem_addr_valid_q}}) |
                               (64'hDEADBEEF_DEADBEEF & {64{~reg_addr_valid & ~mem_addr_valid_q}});
            end
        end
    end

    assign mem_rdata_o = mem_rdata_q;

    ///////////////////////////////////////
    // Octree Core Instantiation
    ///////////////////////////////////////
    

    Octree#(
        .FEATURE_LENGTH              (10                        ),
        .TREE_LEVEL                  (4                         ),
        .ENCODE_ADDR_WIDTH           (3*4+$clog2(4)             ),
        .TREE_START_ADDR             (0                         ),
        .LOD_START_ADDR              (1000                      ),
        .FEATURE_START_ADDR          (74                        ),
        .INPUT_FEATURE_START_ADDR    (0                         ),
        .OUTPUT_FEATURE_START_ADDR   (10                        ) 
    )
     u_Octree(
        .clk                         (clk_i                       ),
        .rst_n                       (rstn_i                     ),
        .csr_pos_encode              (csr_pos_encode            ),// level | offset 0 | offset  1 | offset  2 | offset  3
        .csr_ctrl                    (csr_ctrl                  ),// 0 IDLE; 1 search tree;2 add anchor; 3 delete anchor
        .csr_tree_num                (csr_tree_num              ),// （take 8 for now）
        .csr_op_done                 (csr_op_done               ),// 00 IDLE;01 search_done;02 add_done;03 del_done
        .csr_local_sram_en           (csr_local_sram_en         ),
        .csr_in_out_sram_en          (csr_in_out_sram_en        ),
        .csr_lod_param               (csr_lod_param             ), 
    //in_out_sram for testing
        .axi_in_out_SRAM_req_i       (axi_in_out_SRAM_req_i     ),
        .axi_in_out_SRAM_we_i        (axi_in_out_SRAM_we_i      ),
        .axi_in_out_SRAM_addr_i      (axi_in_out_SRAM_addr_i    ),
        .axi_in_out_SRAM_wdata_i     (axi_in_out_SRAM_wdata_i   ),
        .axi_in_out_SRAM_rdata_o     (axi_in_out_SRAM_rdata_o   ),
    //main_memory
        .axi_local_SRAM_req_i        (axi_local_SRAM_req_i      ),
        .axi_local_SRAM_we_i         (axi_local_SRAM_we_i       ),
        .axi_local_SRAM_addr_i       (axi_local_SRAM_addr_i     ),
        .axi_local_SRAM_wdata_i      (axi_local_SRAM_wdata_i    ),
        .axi_local_SRAM_rdata_o      (axi_local_SRAM_rdata_o    ) 
    );


endmodule
