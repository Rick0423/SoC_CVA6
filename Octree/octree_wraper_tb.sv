//////////////////////////////////////////////////////////////////////////////////
// Company:        OpenAI
// Engineer:       Renati Tuerhong
// Create Date:    2025-07-04
// Design Name:    Octree
// Module Name:    tb_Octree_wrapper
// Project Name:   VLSI-26 3DGS
// Description:    Testbench for Octree_wrapper
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module tb_Octree_wrapper;

    // Clock and reset
    reg                                 clk_i                       ;
    reg                                 rstn_i                      ;

    // SoC bus signals
    reg                  [  63: 0]      sram_data[0:1024]           ;
    reg                                 mem_req_i                   ;
    reg                                 mem_write_en_i              ;
    reg                  [   7: 0]      mem_byte_en_i               ;
    reg                  [  63: 0]      mem_addr_i                  ;
    reg                  [  63: 0]      mem_wdata_i                 ;
    wire                 [  63: 0]      mem_rdata_o                 ;

    logic     [3*4+$clog2(4)-1: 0]      csr_pos_encode              ;
    logic                [   1: 0]      csr_ctrl                    ;
    logic                [   3: 0]      csr_tree_num                ;
    logic                [   1: 0]      csr_op_done                 ;
    logic                               csr_local_sram_en           ;
    logic                               csr_in_out_sram_en          ;
    logic             [4:0][15: 0]      csr_lod_param               ;
    reg                  [  15: 0]      s                           ;
    reg                  [  15: 0]      dist_max                    ;
    reg               [2:0][15: 0]      cam_pos                     ;
    wire                 [  63: 0]      csr_mem_0                   ;
    wire                 [  63: 0]      csr_mem_1                   ;

    // csr_mem[0]: {pos_encode(14b) ,ctrl (2b),tree_num (4b),...,local_sram_en (1b),in_out_sram_en (1b),lod_param[0](16b)}
    // csr_mem[1]: {lod_param[1] , lod_param[2] ,lod_param[3],lod_param[4] }
    assign csr_lod_param = {s,dist_max,cam_pos};
    assign csr_mem_0 = {csr_pos_encode,csr_ctrl,csr_tree_num,26'd0,csr_local_sram_en,csr_in_out_sram_en,csr_lod_param[0]};
    assign csr_mem_1 = {csr_lod_param[1],csr_lod_param[2],csr_lod_param[3],csr_lod_param[4]};

    // Instantiate DUT
    Octree_wrapper dut (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .mem_req_i(mem_req_i),
        .mem_write_en_i(mem_write_en_i),
        .mem_byte_en_i(mem_byte_en_i),
        .mem_addr_i(mem_addr_i),
        .mem_wdata_i(mem_wdata_i),
        .mem_rdata_o(mem_rdata_o)
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; // 100MHz
    end

    // Reset
    initial begin
        rstn_i = 0;
        #20;
        rstn_i = 1;
    end

    // Monitor mem_rdata_o
    initial begin
        $dumpfile("tb_Octree_wrapper.vcd");
        $dumpvars(0, tb_Octree_wrapper);
    end

    // Drive test sequence
    initial begin
        // Initialize inputs
        mem_req_i       = 0;
        mem_write_en_i  = 0;
        mem_byte_en_i   = 8'hFF;
        mem_addr_i      = 0;
        mem_wdata_i     = 0;

        csr_ctrl = 0;
        csr_pos_encode = 0;
        csr_tree_num = 4;
        csr_in_out_sram_en = 0;
        csr_local_sram_en = 0;
        cam_pos = '{16'h3C00, 16'h3C00, 16'h3C00};
        dist_max = 16'b0100100100000000;
        s = 16'b0011110000000000;

        // Wait for reset release
        // csr_mem[0]: {pos_encode(14b) ,ctrl (2b),tree_num (4b),local_sram_en (1b),in_out_sram_en (1b),...,lod_param[0](16b)}
        // csr_mem[1]: {lod_param[1] , lod_param[2] ,lod_param[3],lod_param[4] }

        #100;
        // Write CSR 
        write_CSR();
        #10;
        csr_local_sram_en = 1;
        csr_in_out_sram_en =1;
        csr_tree_num = 4;
        #10;
        write_CSR();

        $readmemh("sram.txt", sram_data);
        for (int i = 0; i < 1024; i = i + 1) begin
            @(posedge clk_i);
            mem_req_i       = 1;
            mem_write_en_i  = 1;
            mem_byte_en_i   = 8'hFF;
            mem_addr_i      = 64'h6010_0000 + i * 8;
            mem_wdata_i     = sram_data[i];
        end
        mem_req_i       =0;
        mem_write_en_i  =0;
        #10;
        
        csr_local_sram_en = 0;
        csr_in_out_sram_en =0;
        csr_ctrl = 2'b01;
        #10
        write_CSR();
        #10
        csr_ctrl = 2'b00;   
        #10
        write_CSR();     
        // 5. Write to in/out SRAM
        write_bus(64'h6020_0000 + 8*2, 64'h1234_5678_9ABC_DEF0);
        // 6. Read back in/out SRAM
        read_bus (64'h6020_0000 + 8*2);
        #2000;
        $display("Testbench completed.");
        $finish;
    end

    // Bus write task
    task write_bus(input [63:0] addr, input [63:0] data);
    begin
        @(posedge clk_i);
        mem_req_i       = 1;
        mem_write_en_i  = 1;
        mem_byte_en_i   = 8'hFF;
        mem_addr_i      = addr;
        mem_wdata_i     = data;
        @(posedge clk_i);
        mem_req_i       = 0;
        mem_write_en_i  = 0;
    end
    endtask

    // Bus read task
    task read_bus(input [63:0] addr);
    begin
        @(posedge clk_i);
        mem_req_i       = 1;
        mem_write_en_i  = 0;
        mem_byte_en_i   = 8'hFF;
        mem_addr_i      = addr;
        @(posedge clk_i);
        mem_req_i       = 0;
        $display("Read from 0x%h: data=0x%h", addr, mem_rdata_o);
    end
    endtask

    task write_CSR();
    begin
        write_bus(64'h6000_0000, csr_mem_0);
        write_bus(64'h6001_0000, csr_mem_1);
    end
    endtask

endmodule
