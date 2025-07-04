module PE_LUT_wrapper(
    input  logic                clk_i           ,
    input  logic                rstn_i          ,
    input  logic                mem_req_i       ,
    input  logic                mem_write_en_i  ,
    input  logic [64/8-1:0]     mem_byte_en_i   ,
    input  logic [64-1:0]       mem_addr_i      ,
    input  logic [64-1:0]       mem_wdata_i     ,
    output logic [64-1:0]       mem_rdata_o
);

    ////////////////// Configurable Register List ///////////////////////////////
    // 1. CSR Mem
    //      - Size: {29'b0, 35-bit} * 16
    //      - Address: 0x6000_0000 ~ 0x6000_0080
    //      - Access: Read/Write
    // 2. CSR Control Register
    //      - Size: {16'b0, 48-bit}
    //      - Address: 0x600f_0000
    //      - [17:0] : Result Config + CSR enable bits, Read/Write
    //      - [47:32] : CSR computation start bits, Read-Only
    //      - [63:48] : CSR result ready bits, Read-Only
    //      - Remaining bits: Reserved
    /////////////////////////////////////////////////////////////////////////////

    ///////////////////////
    // Address Mapping
    ///////////////////////
    localparam logic [64-1:0] CSR_MEM_BASE_ADDR     = 64'h6000_0000;
    localparam logic [64-1:0] CSR_CONTROL_ADDR      = 64'h600f_0000;
    localparam logic [64-1:0] LOCAL_SRAM_BASE_ADDR  = 64'h6010_0000;
    localparam logic [64-1:0] OUTPUT_SRAM_BASE_ADDR = 64'h6020_0000;

    localparam logic [64-1:0] CSR_MEM_LENGTH        = 64'h0000_0080;
    localparam logic [64-1:0] LOCAL_SRAM_LENGTH     = 64'h0002_0000;
    localparam logic [64-1:0] OUTPUT_SRAM_LENGTH    = 64'h0000_8000;


    // register definition
    logic [16-1:0][35-1:0] csr_mem;
    logic [64-1:0]         csr_control;
    logic [18-1:0]         csr_en;
    logic [16-1:0]         csr_cal_start;
    logic [16-1:0]         csr_ready;
    logic [64-1:0]         rdata_reg;
    logic                  reg_addr_valid;
    assign csr_control = {csr_ready, csr_cal_start, 14'b0, csr_en};

    // convert byte enable to bit enable
    logic [64-1:0]         mem_bit_en;
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            mem_bit_en[i*8+:8] = {8{mem_byte_en_i[i]}};
        end
    end


    ///////////////////////////////////////
    // memory-mapped register read & write
    ///////////////////////////////////////
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            csr_mem         <= '0;
            csr_en          <= '0;
            rdata_reg       <= '0;
            reg_addr_valid  <= '0;
        end
        else begin
            // clear register address valid automatically
            reg_addr_valid <= '0;

            // set default rdata value
            rdata_reg <= 64'hCA11AB1EBADCAB1E;

            // write operation
            if (mem_req_i & mem_write_en_i) begin
                case (mem_addr_i[32-4-1:16])
                    // -4 => cut off the first 4 bits (axi region offset)
                    // +3 => cut off the last 3 bits (map byte-aligned address to 64-bit register)
                    // 4  => CSR memory index length
                    CSR_MEM_BASE_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:7] == '0) begin
                            csr_mem[mem_addr_i[4+3-1:0+3]]  <= mem_wdata_i[35-1:0] & mem_bit_en[35-1:0];
                            reg_addr_valid                  <= 1'b1;
                        end
                    end
                    CSR_CONTROL_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:3] == '0) begin
                            csr_en                          <= mem_wdata_i[18-1:0] & mem_bit_en[18-1:0];
                            reg_addr_valid                  <= 1'b1;
                        end
                    end
                endcase
            end

            // read operation
            else if (mem_req_i & !mem_write_en_i) begin
                case (mem_addr_i[32-4-1:16])
                    CSR_MEM_BASE_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:7] == '0) begin
                            rdata_reg      <= csr_mem[mem_addr_i[4+3-1:0+3]];
                            reg_addr_valid <= 1'b1;
                        end
                    end
                    CSR_CONTROL_ADDR[32-4-1:16]: begin
                        if (mem_addr_i[16-1:3] == '0) begin
                            rdata_reg      <= csr_control;
                            reg_addr_valid <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end

    // sram interface crossbar
    logic                local_sram_req         ;
    logic                local_sram_write_en    ;
    logic [64-1:0]       local_sram_addr        ;
    logic [64-1:0]       local_sram_wdata       ;
    logic [64-1:0]       local_sram_rdata       ;

    logic                output_sram_req        ;
    logic                output_sram_write_en   ;
    logic [64-1:0]       output_sram_addr       ;
    logic [64-1:0]       output_sram_wdata      ;
    logic [64-1:0]       output_sram_rdata      ;

    logic [64-1:0]       rdata_mem;
    logic [64-1:0]       rdata_addr_d,rdata_addr_q;
    logic                mem_addr_valid_d, mem_addr_valid_q;

    logic                mem_req_q              ;
    logic                mem_rdata_valid_q      ;
    logic [64-1:0]       mem_rdata_q            ;

    ///////////////////////////////////////
    // memory-mapped sram read & write
    ///////////////////////////////////////
    always_comb begin
        // default value
        local_sram_req         = '0;
        local_sram_write_en    = '0;
        local_sram_addr        = '0;
        local_sram_wdata       = '0;

        output_sram_req        = '0;
        output_sram_write_en   = '0;
        output_sram_addr       = '0;
        output_sram_wdata      = '0;

        rdata_mem              = 64'hCA11AB1EBADCAB1E;
        mem_addr_valid_d       = 1'b0;

        if (mem_req_i) begin
            case (mem_addr_i[32-4-1:20])
                LOCAL_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:17] == '0) begin
                        local_sram_req         = 1'b1                  ;
                        local_sram_write_en    = mem_write_en_i        ;
                        local_sram_addr        = mem_addr_i[14+3-1:3]  ;
                        local_sram_wdata       = mem_wdata_i           ;
                        mem_addr_valid_d       = 1'b1                  ;
                        rdata_addr_d           = mem_addr_i            ;
                    end
                end
                OUTPUT_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:15] == '0) begin
                        output_sram_req        = 1'b1                  ;
                        output_sram_write_en   = mem_write_en_i        ;
                        output_sram_addr       = mem_addr_i[12+3-1:3]  ;
                        output_sram_wdata      = mem_wdata_i           ;
                        mem_addr_valid_d       = 1'b1                  ;
                        rdata_addr_d           = mem_addr_i            ;
                    end
                end
            endcase
        end

        if (mem_addr_valid_q) begin
            case (mem_addr_i[32-4-1:20])
                LOCAL_SRAM_BASE_ADDR[32-4-1:20]: begin
                    if (mem_addr_i[20-1:18] == '0) begin
                        rdata_mem = local_sram_rdata;
                    end
                end
                OUTPUT_SRAM_BASE_ADDR[32-4-1:15]: begin
                    if (mem_addr_i[20-1:15] == '0) begin
                        rdata_mem = output_sram_rdata;
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            mem_addr_valid_q       <= 1'b0;
            rdata_addr_q           <= '0;
        end else begin
            mem_addr_valid_q       <= mem_addr_valid_d;
            rdata_addr_q           <= rdata_addr_d;
        end
    end

    // choose output rdata from register or sram
    always_ff @(posedge clk_i or negedge rstn_i ) begin
        if(!rstn_i) begin
            mem_req_q <= 1'b0;
        end else begin
            mem_req_q <= mem_req_i;
        end
    end

    always_ff @(posedge clk_i or negedge rstn_i ) begin
        if(!rstn_i) begin
            mem_rdata_valid_q <= 1'b0;
            mem_rdata_q       <= '0;
        end else if(mem_req_q) begin
            mem_rdata_valid_q <= 1'b1;
            mem_rdata_q       <= (rdata_reg & {64{reg_addr_valid}}) | (rdata_mem & {64{mem_addr_valid_q}}) | 
                                 (64'hCA11AB1EBADCAB1E & {64{~reg_addr_valid & ~mem_addr_valid_q}});
        end else begin
            mem_rdata_valid_q <= 1'b1;
            mem_rdata_q       <= mem_rdata_q;
        end
    end

    assign mem_rdata_valid_o = mem_rdata_valid_q;
    assign mem_rdata_o = mem_rdata_q;

    ///////////////////////////////////////
    // PE_LUT_Accelerator instantiation
    ///////////////////////////////////////
    PE_LUT_Accelerator pe_lut_accelerator_inst(
        .clk                          (clk_i               ),
        .rst_n                        (rstn_i              ),

        .local_sram_req_i             (local_sram_req      ),
        .local_sram_we_i              (local_sram_write_en ),
        .local_sram_addr_i            (local_sram_addr     ),
        .local_sram_wdata_i           (local_sram_wdata    ),
        .local_sram_rdata_o           (local_sram_rdata    ),

        .output_sram_req_i            (output_sram_req     ),
        .output_sram_we_i             (output_sram_write_en),
        .output_sram_addr_i           (output_sram_addr    ),
        .output_sram_wdata_i          (output_sram_wdata   ),
        .output_sram_rdata_o          (output_sram_rdata   ),

        .csr_en_i                     (csr_en              ),
        .csr0_i                       (csr_mem[0]          ),
        .csr1_i                       (csr_mem[1]          ),
        .csr2_i                       (csr_mem[2]          ),
        .csr3_i                       (csr_mem[3]          ),
        .csr4_i                       (csr_mem[4]          ),
        .csr5_i                       (csr_mem[5]          ),
        .csr6_i                       (csr_mem[6]          ),
        .csr7_i                       (csr_mem[7]          ),
        .csr8_i                       (csr_mem[8]          ),
        .csr9_i                       (csr_mem[9]          ),
        .csr10_i                      (csr_mem[10]         ),
        .csr11_i                      (csr_mem[11]         ),
        .csr12_i                      (csr_mem[12]         ),
        .csr13_i                      (csr_mem[13]         ),
        .csr14_i                      (csr_mem[14]         ),
        .csr15_i                      (csr_mem[15]         ),
        .csr_result_config_i          (csr_en[17:16]       ),

        .csr_cal_start_o              (csr_cal_start       ),
        .csr_ready_o                  (csr_ready           )
    );

endmodule