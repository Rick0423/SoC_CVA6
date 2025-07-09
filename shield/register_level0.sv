
module register_level0 #(
    parameter data_width = 3*16,
    parameter addr_width = 4,
    parameter depth      = 10
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