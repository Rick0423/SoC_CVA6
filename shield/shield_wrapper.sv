`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-09
// Design Name:     Shield
// Project Name:    VLSI-26 3DGS
// Description:     Connect Shield to SoC
//////////////////////////////////////////////////////////////////////////////////
module shield_top_wrapper(
    input                               clk_i                      ,
    input                               rstn_i                     ,
    input                               mem_req_i                  ,
    input                               mem_write_en_i             ,
    input                [64/8-1: 0]    mem_byte_en_i              ,
    input                [64-1: 0]      mem_addr_i                 ,
    input                [64-1: 0]      mem_wdata_i                ,
    output               [64-1: 0]      mem_rdata_o                 
);

    ////////////////////////////////
    // CSR and Address Mapping
    ////////////////////////////////
    // CSR fields: start_anchor_shield (1b), start_oct_shield (1b), start_get0 (1b),
    //             block_x_idx (3b), block_y_idx (3b), fx (16b), fy (16b), zlength (16b), delay (8b),
    //             distance_thresold (16b), num_thresold (16b),
    //             anchor_shield_addr_end (7b), anchor_shield_addr_start (7b),
    //             oct_shield_addr_end (4b), oct_shield_addr_start (4b),
    //             get0_addr_end (7b), get0_addr_start (7b),
    //             level0_reg_en (1b), block_sram_en (1b), output_sram_en (1b), input_sram_en (1b).
    // CSR_MEM[0]: {input_en (1b), output_en (1b), block_en (1b), level0_en (1b),
    //             get0_start (1b), oct_start (1b), anchor_start (1b),
    //             get0_addr_start (7b), get0_addr_end (7b),
    //             oct_addr_start (4b), oct_addr_end (4b),
    //             anchor_addr_start (7b), anchor_addr_end (7b)}
    // CSR_MEM[1]: {delay (8b), zlength (16b), fy (16b), fx (16b), block_y_idx (3b), block_x_idx (3b)}
    // CSR_MEM[2]: {num_thresold (16b), distance_thresold (16b)}
    // CSR_MEM[3..6]: viewmetrics 4x16b (total 256b, 4 * 64b words)
    localparam logic [64-1:0] CSR_MEM_BASE_ADDR      = 64'h7000_0000;
    localparam logic [8:0]    CSR_MEM_DEPTH          = 7;             //  7  CSR_MEM_x
    localparam logic [64-1:0] CSR_CONTROL_ADDR       = 64'h700f_0000;

    localparam logic [64-1:0] INPUT_SRAM_BASE_ADDR   = 64'h7010_0000;
    localparam logic [64-1:0] INPUT_SRAM_LENGTH      = 64'h0000_2000; // 8KB
    localparam logic [64-1:0] LEVEL0_SRAM_BASE_ADDR  = 64'h7020_0000;
    localparam logic [64-1:0] LEVEL0_SRAM_LENGTH     = 64'h0000_2000; // 8KB
    localparam logic [64-1:0] OUTPUT_SRAM_BASE_ADDR  = 64'h7030_0000;
    localparam logic [64-1:0] OUTPUT_SRAM_LENGTH     = 64'h0000_2000; // 8KB
    localparam logic [64-1:0] BLOCK_SRAM_BASE_ADDR   = 64'h7040_0000;
    localparam logic [64-1:0] BLOCK_SRAM_LENGTH      = 64'h0000_2000; // 8KB

    localparam      DATA_WIDTH                  = 16    ;
    localparam      ANCHOR_ADDR_WIDTH           = 7     ;
    localparam      ANCHOR_DATA_WIDTH           = 64    ;                
    localparam      LEVEL_ADDR_WIDTH            = 4     ;                
    localparam      LEVEL_DATA_WIDTH            = 48    ;                
    localparam      BLOCK_ADDR_WIDTH            = 6     ;                
    localparam      BLOCK_DATA_WIDTH            = 64    ;                
    localparam      SAVE_ADDR_WIDTH             = 7     ;                
    localparam      SAVE_DATA_WIDTH             = 64    ;  

    // Internal CSR registers
    logic                [6:0][63: 0]      csr_mem                     ;
    // Decompressed CSR fields
    logic                               csr_start_anchor_shield     ;
    logic                               csr_start_oct_shield        ;
    logic                               csr_start_get0              ;
    logic                [   2: 0]      csr_block_x_idx             ;
    logic                [   2: 0]      csr_block_y_idx             ;
    logic        [DATA_WIDTH-1: 0]      csr_fx                      ;
    logic        [DATA_WIDTH-1: 0]      csr_fy                      ;
    logic        [DATA_WIDTH-1: 0]      csr_zlength                 ;
    logic                [   7: 0]      csr_delay                   ;
    logic        [DATA_WIDTH-1: 0]      csr_distance_thresold       ;
    logic        [DATA_WIDTH-1: 0]      csr_num_thresold            ;
    logic [ANCHOR_ADDR_WIDTH-1: 0]      csr_anchor_shield_addr_end  ;
    logic [ANCHOR_ADDR_WIDTH-1: 0]      csr_anchor_shield_addr_start  ;
    logic  [LEVEL_ADDR_WIDTH-1: 0]      csr_oct_shield_addr_end     ;
    logic  [LEVEL_ADDR_WIDTH-1: 0]      csr_oct_shield_addr_start   ;
    logic [ANCHOR_ADDR_WIDTH-1: 0]      csr_get0_addr_end           ;
    logic [ANCHOR_ADDR_WIDTH-1: 0]      csr_get0_addr_start         ;
    logic                               csr_level0_reg_en           ;
    logic                               csr_block_sram_en           ;
    logic                               csr_output_sram_en          ;
    logic                               csr_input_sram_en           ;
    logic[3:0][3:0][DATA_WIDTH-1:0]     csr_viewmetrics ;
    logic                [  31: 0]      csr_total_effective_anchor  ;
    logic                               csr_done_anchor_shield      ;
    logic                               csr_done_oct_shield         ;
    logic                               csr_done_get0               ;

    // SRAM interface signals for shield_top instance
    logic                               axi_input_sram_cen_n_i      ;
    logic                               axi_input_sram_wen_i        ;
    logic [ANCHOR_ADDR_WIDTH-1: 0]      axi_input_sram_addr_i       ;
    logic [ANCHOR_DATA_WIDTH-1: 0]      axi_input_sram_data_in_i    ;
    logic [ANCHOR_DATA_WIDTH-1: 0]      axi_input_sram_data_out_o   ;

    logic                               axi_output_sram_cen_n_i     ;
    logic                               axi_output_sram_wen_i       ;
    logic   [SAVE_ADDR_WIDTH-1: 0]      axi_output_sram_addr_i      ;
    logic   [SAVE_DATA_WIDTH-1: 0]      axi_output_sram_data_in_i   ;
    logic   [SAVE_DATA_WIDTH-1: 0]      axi_output_sram_data_out_o  ;

    logic                               axi_level0_reg_cen_n_i      ;
    logic                               axi_level0_reg_wen_i        ;
    logic  [LEVEL_ADDR_WIDTH-1: 0]      axi_level0_reg_addr_i       ;
    logic  [LEVEL_DATA_WIDTH-1: 0]      axi_level0_reg_data_in_i    ;
    logic  [LEVEL_DATA_WIDTH-1: 0]      axi_level0_reg_data_out_o   ;

    logic                               axi_block_sram_cen_n_i      ;
    logic                               axi_block_sram_wen_i        ;
    logic  [BLOCK_ADDR_WIDTH-1: 0]      axi_block_sram_addr_i       ;
    logic  [BLOCK_DATA_WIDTH-1: 0]      axi_block_sram_data_in_i    ;
    logic  [BLOCK_DATA_WIDTH-1: 0]      axi_block_sram_data_out_o   ;

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

    /////////////////////////////////////
    // memory-mapped CSR read & write
    /////////////////////////////////////

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            csr_mem         <= '0;
            rdata_reg       <= '0;
            reg_addr_valid  <= 1'b0;
        end
        else begin
            // clear register address valid
            reg_addr_valid <= 1'b0;
            // default read data
            rdata_reg      <= 64'hCA11AB1EBADCAB1E;

            // write operation
            if (mem_req_i & mem_write_en_i) begin
                case (mem_addr_i[32-4-1:16])  // [27:16]
                    CSR_MEM_BASE_ADDR[32-4-1:16]: begin
                        // indices 0..CSR_MEM_DEPTH-1
                        if (mem_addr_i[16-1:7] < CSR_MEM_DEPTH) begin
                            // map byte-align addr to 64-bit word index
                            csr_mem[mem_addr_i[4+3-1:0+3]] <= mem_wdata_i & mem_bit_en;
                            reg_addr_valid                 <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            // read operation
            else if (mem_req_i & !mem_write_en_i) begin
                case (mem_addr_i[32-4-1:16])  // [27:16]
                    CSR_MEM_BASE_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:7] < CSR_MEM_DEPTH) begin
                            rdata_reg      <= csr_mem[mem_addr_i[4+3-1:0+3]];
                            reg_addr_valid <= 1'b1;
                        end
                    end
                    CSR_CONTROL_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:3] == 13'b0) begin
                            rdata_reg      <= {29'd0,
                                               csr_total_effective_anchor,
                                               csr_done_anchor_shield,
                                               csr_done_oct_shield,
                                               csr_done_get0};
                            reg_addr_valid <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    // Assign CSR register fields from memory
    assign csr_anchor_shield_addr_end   = csr_mem[0][6:0];
    assign csr_anchor_shield_addr_start = csr_mem[0][13:7];
    assign csr_oct_shield_addr_end      = csr_mem[0][17:14];
    assign csr_oct_shield_addr_start    = csr_mem[0][21:18];
    assign csr_get0_addr_end            = csr_mem[0][28:22];
    assign csr_get0_addr_start          = csr_mem[0][35:29];
    assign csr_start_anchor_shield      = csr_mem[0][36];
    assign csr_start_oct_shield         = csr_mem[0][37];
    assign csr_start_get0               = csr_mem[0][38];
    assign csr_level0_reg_en            = csr_mem[0][39];
    assign csr_block_sram_en            = csr_mem[0][40];
    assign csr_output_sram_en           = csr_mem[0][41];
    assign csr_input_sram_en            = csr_mem[0][42];

    assign csr_block_x_idx              = csr_mem[1][2:0];
    assign csr_block_y_idx              = csr_mem[1][5:3];
    assign csr_fx                       = csr_mem[1][21:6];
    assign csr_fy                       = csr_mem[1][37:22];
    assign csr_zlength                  = csr_mem[1][53:38];
    assign csr_delay                    = csr_mem[1][61:54];

    assign csr_distance_thresold        = csr_mem[2][15:0];
    assign csr_num_thresold             = csr_mem[2][31:16];

    assign csr_viewmetrics[0][0]        = csr_mem[3][63:48];
    assign csr_viewmetrics[0][1]        = csr_mem[3][47:32];
    assign csr_viewmetrics[0][2]        = csr_mem[3][31:16];
    assign csr_viewmetrics[0][3]        = csr_mem[3][15:0];
    assign csr_viewmetrics[1][0]        = csr_mem[4][63:48];
    assign csr_viewmetrics[1][1]        = csr_mem[4][47:32];
    assign csr_viewmetrics[1][2]        = csr_mem[4][31:16];
    assign csr_viewmetrics[1][3]        = csr_mem[4][15:0];
    assign csr_viewmetrics[2][0]        = csr_mem[5][63:48];
    assign csr_viewmetrics[2][1]        = csr_mem[5][47:32];
    assign csr_viewmetrics[2][2]        = csr_mem[5][31:16];
    assign csr_viewmetrics[2][3]        = csr_mem[5][15:0];
    assign csr_viewmetrics[3][0]        = csr_mem[6][63:48];
    assign csr_viewmetrics[3][1]        = csr_mem[6][47:32];
    assign csr_viewmetrics[3][2]        = csr_mem[6][31:16];
    assign csr_viewmetrics[3][3]        = csr_mem[6][15:0];

    /////////////////////////////
    // SRAM interface crossbar
    /////////////////////////////
    // Default assignments
    logic                [64-1: 0]      rdata_mem                   ;
    logic                               mem_addr_valid_d            ,         
                                        mem_addr_valid_q            ;
    logic                [64-1: 0]      rdata_addr_d                ,             
                                        rdata_addr_q                ;
    logic                               mem_req_q                   ;
    logic                [64-1: 0]      mem_rdata_q                 ;
    logic                               mem_rdata_valid_q           ;

    // Default outputs low
    always_comb begin
        // Default no SRAM request or data
        axi_input_sram_cen_n_i        = 1'b1;
        axi_input_sram_wen_i         = 1'b0;
        axi_input_sram_addr_i        = '0;
        axi_input_sram_data_in_i     = 64'b0;

        axi_output_sram_cen_n_i       = 1'b1;
        axi_output_sram_wen_i        = 1'b0;
        axi_output_sram_addr_i       = '0;
        axi_output_sram_data_in_i    = 64'b0;

        axi_level0_reg_cen_n_i        = 1'b1;
        axi_level0_reg_wen_i         = 1'b0;
        axi_level0_reg_addr_i        = '0;
        axi_level0_reg_data_in_i     = 48'b0;

        axi_block_sram_cen_n_i        = 1'b1;
        axi_block_sram_wen_i         = 1'b0;
        axi_block_sram_addr_i        = '0;
        axi_block_sram_data_in_i     = 64'b0;

        rdata_mem                   = 64'hDEADBEEF_DEADBEEF;
        mem_addr_valid_d            = 1'b0;

        if (mem_req_i) begin
            case (mem_addr_i[32-4-1:20]) // [27:20]
                INPUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_input_sram_cen_n_i    = 1'b0;
                        axi_input_sram_wen_i     = mem_write_en_i;
                        axi_input_sram_addr_i    = mem_addr_i[9:3];
                        axi_input_sram_data_in_i = mem_wdata_i;
                        mem_addr_valid_d         = 1'b1;
                        rdata_addr_d            = mem_addr_i;
                    end
                end
                LEVEL0_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_level0_reg_cen_n_i    = 1'b0;
                        axi_level0_reg_wen_i      = mem_write_en_i;
                        axi_level0_reg_addr_i     = mem_addr_i[6:3];
                        axi_level0_reg_data_in_i  = mem_wdata_i[47:0];//48bit data
                        mem_addr_valid_d          = 1'b1;
                        rdata_addr_d             = mem_addr_i;
                    end
                end
                OUTPUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_output_sram_cen_n_i   = 1'b0;
                        axi_output_sram_wen_i     = mem_write_en_i;
                        axi_output_sram_addr_i    = mem_addr_i[9:3];
                        axi_output_sram_data_in_i = mem_wdata_i;
                        mem_addr_valid_d          = 1'b1;
                        rdata_addr_d             = mem_addr_i;
                    end
                end
                BLOCK_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:13] == '0) begin
                        axi_block_sram_cen_n_i    = 1'b0;
                        axi_block_sram_wen_i      = mem_write_en_i;
                        axi_block_sram_addr_i     = mem_addr_i[8:3];
                        axi_block_sram_data_in_i  = mem_wdata_i;
                        mem_addr_valid_d          = 1'b1;
                        rdata_addr_d             = mem_addr_i;
                    end
                end
                default: ;
            endcase
        end

        // Read from the SRAM that was addressed one cycle ago
        if (mem_addr_valid_q) begin
            case (rdata_addr_q[32-4-1:20])
                INPUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = axi_input_sram_data_out_o;
                    end
                end
                LEVEL0_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = {16'd0,axi_level0_reg_data_out_o};
                    end
                end
                OUTPUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = axi_output_sram_data_out_o;
                    end
                end
                BLOCK_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (rdata_addr_q[20-1:13] == '0) begin
                        rdata_mem = axi_block_sram_data_out_o;
                    end
                end
                default: begin
                    rdata_mem = 64'hDEADBEEF_DEADBEEF;
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
    // Shield Core Instantiation
    ///////////////////////////////////////

shield_top#(
    .DATA_WIDTH                  (DATA_WIDTH                ),
    .ANCHOR_ADDR_WIDTH           (ANCHOR_ADDR_WIDTH         ),
    .ANCHOR_DATA_WIDTH           (ANCHOR_DATA_WIDTH         ),
    .LEVEL_ADDR_WIDTH            (LEVEL_ADDR_WIDTH          ),
    .LEVEL_DATA_WIDTH            (LEVEL_DATA_WIDTH          ),
    .BLOCK_ADDR_WIDTH            (BLOCK_ADDR_WIDTH          ),
    .BLOCK_DATA_WIDTH            (BLOCK_DATA_WIDTH          ),
    .SAVE_ADDR_WIDTH             (SAVE_ADDR_WIDTH           ),
    .SAVE_DATA_WIDTH             (SAVE_DATA_WIDTH           ) 
)
 u_shield_top(
    .clk                         (clk_i                     ),
    .rst_n                       (rstn_i                    ),

    .csr_viewmetrics             (csr_viewmetrics           ),
    .csr_start_anchor_shield     (csr_start_anchor_shield   ),
    .csr_start_oct_shield        (csr_start_oct_shield      ),
    .csr_start_get0              (csr_start_get0            ),
    .csr_fx                      (csr_fx                    ),
    .csr_fy                      (csr_fy                    ),
    .csr_block_x_idx             (csr_block_x_idx           ),
    .csr_block_y_idx             (csr_block_y_idx           ),
    .csr_zlength                 (csr_zlength               ),
    .csr_delay                   (csr_delay                 ),
    .csr_distance_thresold       (csr_distance_thresold     ),
    .csr_num_thresold            (csr_num_thresold          ),
    .csr_anchor_shield_addr_end  (csr_anchor_shield_addr_end),
    .csr_anchor_shield_addr_start(csr_anchor_shield_addr_start),
    .csr_oct_shield_addr_end     (csr_oct_shield_addr_end   ),
    .csr_oct_shield_addr_start   (csr_oct_shield_addr_start ),
    .csr_get0_addr_end           (csr_get0_addr_end         ),
    .csr_get0_addr_start         (csr_get0_addr_start       ),
    .csr_total_effective_anchor  (csr_total_effective_anchor),
    .csr_done_anchor_shield      (csr_done_anchor_shield    ),
    .csr_done_oct_shield         (csr_done_oct_shield       ),
    .csr_done_get0               (csr_done_get0             ),
    .csr_level0_reg_en           (csr_level0_reg_en         ),
    .csr_block_sram_en           (csr_block_sram_en         ),
    .csr_output_sram_en          (csr_output_sram_en        ),
    .csr_input_sram_en           (csr_input_sram_en         ),

    .axi_level0_reg_cen_n_i      (axi_level0_reg_cen_n_i    ),
    .axi_level0_reg_wen_i        (axi_level0_reg_wen_i      ),
    .axi_level0_reg_addr_i       (axi_level0_reg_addr_i     ),
    .axi_level0_reg_data_in_i    (axi_level0_reg_data_in_i  ),
    .axi_level0_reg_data_out_o   (axi_level0_reg_data_out_o ),

    .axi_block_sram_cen_n_i      (axi_block_sram_cen_n_i    ),
    .axi_block_sram_wen_i        (axi_block_sram_wen_i      ),
    .axi_block_sram_addr_i       (axi_block_sram_addr_i     ),
    .axi_block_sram_data_in_i    (axi_block_sram_data_in_i  ),
    .axi_block_sram_data_out_o   (axi_block_sram_data_out_o ),

    .axi_output_sram_cen_n_i     (axi_output_sram_cen_n_i   ),
    .axi_output_sram_wen_i       (axi_output_sram_wen_i     ),
    .axi_output_sram_addr_i      (axi_output_sram_addr_i    ),
    .axi_output_sram_data_in_i   (axi_output_sram_data_in_i ),
    .axi_output_sram_data_out_o  (axi_output_sram_data_out_o),

    .axi_input_sram_cen_n_i      (axi_input_sram_cen_n_i    ),
    .axi_input_sram_wen_i        (axi_input_sram_wen_i      ),
    .axi_input_sram_addr_i       (axi_input_sram_addr_i     ),
    .axi_input_sram_data_in_i    (axi_input_sram_data_in_i  ),
    .axi_input_sram_data_out_o   (axi_input_sram_data_out_o ) 
);


endmodule
