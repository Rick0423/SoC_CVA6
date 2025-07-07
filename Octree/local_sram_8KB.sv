//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-04
// Update Date:     2025-07-06
// Design Name:     Octree
// Project Name:    VLSI-26 3DGS
// Description:     Behaviour simulation of local_Sram
//////////////////////////////////////////////////////////////////////////////////
module local_sram_8KB #(
    parameter ADDR_WIDTH = 10,// Address width: 10 bits to address 1024 entries (8KB of 8-byte words)
    parameter DATA_WIDTH = 64,// Data width: 64 bits
    parameter MEM_DEPTH  = 1 << ADDR_WIDTH,// Memory depth derived from address width
    parameter INIT_FILE  = "sram_init.hex"// Optional initialization file (hex format)
) (
    input                       clk,        // Clock
    input                       rst_n,      // Active-low reset
    input                       sram_req_i, // Chip enable (active high)
    input                       sram_we_i,  // Write enable (active high)
    input   [ADDR_WIDTH-1:0]    sram_addr_i, // Address bus
    input   [DATA_WIDTH-1:0]    sram_wdata_i, // Write data bus
    output  [DATA_WIDTH-1:0]    sram_rdata_o  // Read data bus
);

    // Memory array: MEM_DEPTH entries of DATA_WIDTH bits
    logic [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    // Read data register
    logic [DATA_WIDTH-1:0] rdata_reg;

    // Output assignment
    assign sram_rdata_o = rdata_reg;

    // Optional initialization
//    initial begin
//        if (INIT_FILE != "") begin
//            $readmemh(INIT_FILE, memory);
//        end
//    end

    // Synchronous read/write operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_reg <= {DATA_WIDTH{1'b0}};
        end else if (sram_req_i) begin
            if (sram_we_i) begin
                // Write operation
                memory[sram_addr_i] <= sram_wdata_i;
            end else begin
                // Read operation
                rdata_reg <= memory[sram_addr_i];
            end
        end
    end

endmodule
