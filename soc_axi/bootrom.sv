/* Description: Auto-generated bootrom */

// Auto-generated code
module bootrom (
   input  logic         clk_i,
   input  logic         req_i,
   input  logic [63:0]  addr_i,
   output logic [63:0]  rdata_o
);
    localparam int RomSize = 11;

`ifdef SIM
/*
				_start:
					li sp, 0x80020000
					li ra, 0x80000000
					jr ra

				_hang:
					li sp, 0x80020000
					li ra, 0x80000000
					j _hang
*/
    const logic [RomSize-1:0][63:0] mem = {
        64'hfedff06f_01f09093,
        64'h0010009b_01111113,
        64'h0011011b_00004137,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00008067_01f09093,
        64'h0010009b_01111113,
        64'h0011011b_00004137
    };
`else
/*
				_start:
					li sp, 0x80020000
					li ra, 0x80000000
					sd zero, 0(ra)
					sd zero, 8(ra)
					sd zero, 16(ra)
					sd zero, 24(ra)
					jr ra

				_hang:
					li sp, 0x80020000
					li ra, 0x80000000
					j _hang
*/
    const logic [RomSize-1:0][63:0] mem = {
        64'hfedff06f_01f09093,
        64'h0010009b_01111113,
        64'h0011011b_00004137,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00008067_0000bc23,
        64'h0000b823_0000b423,
        64'h0000b023_01f09093,
        64'h0010009b_01111113,
        64'h0011011b_00004137
    };
`endif

    logic [$clog2(RomSize)-1:0] addr_q;

    always_ff @(posedge clk_i) begin
        if (req_i) begin
            addr_q <= addr_i[$clog2(RomSize)-1+3:3];
        end
    end

    // this prevents spurious Xes from propagating into
    // the speculative fetch stage of the core
    assign rdata_o = (addr_q < RomSize) ? mem[addr_q] : '0;
endmodule

