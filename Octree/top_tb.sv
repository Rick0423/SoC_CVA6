`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-08
// Update Date:     2025-07-10
// Design Name:     Octree_wrapper_tb
// Project Name:    VLSI-26 3DGS
// Description:     testbench for wrapper 
//////////////////////////////////////////////////////////////////////////////////
module tb_top;

    // Clock and reset
    reg         clk_i;
    reg         rstn_i;

    // SoC bus signals
    reg [63:0] sram_data[0:1024];
    reg        mem_req_i;
    reg        mem_write_en_i;
    reg [7:0]  mem_byte_en_i;
    reg [63:0] mem_addr_i;
    reg [63:0] mem_wdata_i;
    wire [63:0] mem_rdata_o;

    // CSR signals
    logic [3*4+$clog2(4)-1:0] csr_pos_encode;
    logic [1:0]             csr_ctrl;
    logic [3:0]             csr_tree_num;
    logic [1:0]             csr_op_done;
    logic                   csr_local_sram_en;
    logic                   csr_in_out_sram_en;
    logic [4:0][15:0]       csr_lod_param;
    reg  [15:0]             s;
    reg  [15:0]             dist_max;
    reg [2:0][15:0]         cam_pos;
    wire [63:0]             csr_mem_0;
    wire [63:0]             csr_mem_1;

    // CSR concatenation
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

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_top);
    end


    /////////////////////////////////////////
    // Clock generation and reset sequence
    /////////////////////////////////////////
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    initial begin
        rstn_i = 0;
        #20 rstn_i = 1;
    end

    /////////////////////////////////////////
    // Test sequence divided into phases
    /////////////////////////////////////////
    initial begin
        // Phase 1: Initialization
        init_phase();
        // Phase 2: Delete Anchor
        delete_anchor_phase();
        // Phase 3: Add Anchor
        add_anchor_phase();
        // Phase 4: Search Tree
        search_tree_phase();
        //Phase 5: Read out 
        read_back();
        $finish;
    end

    /////////////////////////////////////////////////////
    // Phase 1: Initialization
    /////////////////////////////////////////////////////
    task init_phase();
    begin

        // Default bus signals
        mem_req_i      = 0;
        mem_write_en_i = 0;
        mem_byte_en_i  = 8'hFF;
        mem_addr_i     = 0;
        mem_wdata_i    = 0;

        // CSR default values
        csr_ctrl           = 2'b00;
        csr_pos_encode     = {2'd3,3'd0,3'd1,3'd1,3'd0};
        csr_tree_num       = 4;
        csr_local_sram_en  = 1;
        csr_in_out_sram_en = 1;
        cam_pos            = '{16'h3C00,16'h3C00,16'h3C00};
        dist_max           = 16'b0100100100000000;
        s                  = 16'b0011110000000000;

        // Wait for reset release and apply CSR write
        #100;
        write_CSR();
        #10;

        // Load local SRAM
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
        for (int i = 0; i < 10; i = i + 1) begin
            @(posedge clk_i);
            mem_req_i       = 1;
            mem_write_en_i  = 1;
            mem_byte_en_i   = 8'hFF;
            mem_addr_i      = 64'h6020_0000 + i * 8;
            mem_wdata_i     = sram_data[i];
        end
        mem_req_i       =0;
        mem_write_en_i  =0;
        #10;
    end
    endtask

    /////////////////////////////////////////////////////
    // Phase 2: Delete Anchor
    /////////////////////////////////////////////////////
    task delete_anchor_phase();
    begin
        // Set control to delete anchor
        #10
        csr_local_sram_en  = 0;
        csr_in_out_sram_en = 0;
        csr_ctrl           = 2'b11;
        #10 write_CSR();

        // Poll for completion
        wait_op_done();
    end
    endtask

    /////////////////////////////////////////////////////
    // Phase 3: Add Anchor
    /////////////////////////////////////////////////////
    task add_anchor_phase();
    begin
        // Set control to add anchor
        #10
        csr_ctrl = 2'b10;
        #10 write_CSR();

        // Poll for completion
        wait_op_done();
    end
    endtask

    /////////////////////////////////////////////////////
    // Phase 4: Search Tree
    /////////////////////////////////////////////////////
    task search_tree_phase();
    begin
        // Set control to search tree
        #10
        csr_ctrl = 2'b01;
        #10 write_CSR();

        // Allow search to run
        #2000;
        wait_op_done();
    end
    endtask


    /////////////////////////////////////////////////////
    // Phase 5: Read back 
    /////////////////////////////////////////////////////
    task read_back();
    begin
        // Read back results from in/out SRAM
        #10
        csr_local_sram_en  = 1;
        csr_in_out_sram_en = 1;
        #10
        write_CSR();
        #10
        for (int i = 0; i < 1024; i++) begin
            @(posedge clk_i);
            mem_req_i      = 1;
            mem_write_en_i = 0;
            mem_byte_en_i  = 8'hFF;
            mem_addr_i     = 64'h6020_0000 + i*8;
        end
    end
    endtask

    /////////////////////////////////////////////////////
    // Helper tasks
    /////////////////////////////////////////////////////
    task write_bus(input [63:0] addr, input [63:0] data);
    begin
        @(posedge clk_i);
        mem_req_i      = 1;
        mem_write_en_i = 1;
        mem_byte_en_i  = 8'hFF;
        mem_addr_i     = addr;
        mem_wdata_i    = data;
        @(posedge clk_i);
        mem_req_i      = 0;
        mem_write_en_i = 0;
    end
    endtask

    task read_bus(input [63:0] addr);
    begin
        @(posedge clk_i);
        mem_req_i      = 1;
        mem_write_en_i = 0;
        mem_byte_en_i  = 8'hFF;
        mem_addr_i     = addr;
        @(posedge clk_i);
        mem_req_i      = 0;
        $display("Read from 0x%h: data=0x%h", addr, mem_rdata_o);
    end
    endtask

    task write_CSR();
    begin
        write_bus(64'h6000_0000, csr_mem_0);
        write_bus(64'h6001_0000, csr_mem_1);
    end
    endtask

    task wait_op_done();
    begin
        for (int i = 0; i < 3000; i++) begin
            @(posedge clk_i);
            mem_req_i      = 1;
            mem_write_en_i = 0;
            mem_byte_en_i  = 8'hFF;
            mem_addr_i     = 64'h600f_0000;
            @(posedge clk_i);
            mem_req_i      = 0;
            if ((mem_rdata_o != 64'hDEADBEEF_DEADBEEF) && (mem_rdata_o != 64'd0)) // not IDLE
                break;
        end
    end
    endtask

endmodule
