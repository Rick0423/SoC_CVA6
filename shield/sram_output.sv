
module sram_output #(
    parameter data_width = 4*16,
    parameter addr_width = 10,
    parameter depth      = 1024
)(
    input  logic clk,
    input  logic cen_n,
    input  logic wen,
    input  logic [addr_width-1:0] addr,
    input  logic [data_width-1:0] data_in,
    output logic [data_width-1:0] data_out
);

    logic [data_width-1:0] mem [0:depth-1];


    always_ff @(posedge clk) begin
        if (!cen_n) begin
            if (wen) begin
                mem[addr] <= data_in;
            end 
            data_out <= mem[addr];
        end
    end
endmodule