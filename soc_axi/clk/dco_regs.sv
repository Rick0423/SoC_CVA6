//------------------------------------------------------------------------------
// Description: DCO Configuration Registers
// Author:      Zhantong Zhu <zhu_20021122@stu.pku.edu.cn> [Peking University]
//------------------------------------------------------------------------------

module dco_regs #(
	parameter type reg_req_t = logic,
	parameter type reg_rsp_t = logic
)(
	input  logic       clk,
	input  logic       rst_n,
	output logic [5:0] cc_sel_o,
	output logic [5:0] fc_sel_o,
	output logic [2:0] div_sel_o,
	output logic [1:0] freq_sel_o,
	// Bus Interface
	input  reg_req_t req_i,
	output reg_rsp_t rsp_o
);


logic [5:0] cc_sel_d, cc_sel_q, cc_sel_temp;
logic       cc_sel_we;
logic [5:0] fc_sel_d, fc_sel_q, fc_sel_temp;
logic       fc_sel_we;
logic [2:0] div_sel_d, div_sel_q, div_sel_temp;
logic       div_sel_we;
logic [1:0] freq_sel_d, freq_sel_q, freq_sel_temp;
logic       freq_sel_we;

assign cc_sel_o   = cc_sel_q;
assign fc_sel_o   = fc_sel_q;
assign div_sel_o  = div_sel_q;
assign freq_sel_o = freq_sel_q;

assign cc_sel_d   = cc_sel_we   ? cc_sel_temp   : cc_sel_q;
assign fc_sel_d   = fc_sel_we   ? fc_sel_temp   : fc_sel_q;
assign div_sel_d  = div_sel_we  ? div_sel_temp  : div_sel_q;
assign freq_sel_d = freq_sel_we ? freq_sel_temp : freq_sel_q;

always_ff @(posedge clk or negedge rst_n) begin
	// Initialization for DCO
	if (~rst_n) begin
		cc_sel_q <= 6'b111_111;
		fc_sel_q <= 6'b111_111;
		div_sel_q <= 3'b100;
		freq_sel_q <= 2'b11;
	end
	else begin
		cc_sel_q <= cc_sel_d;
		fc_sel_q <= fc_sel_d;
		div_sel_q <= div_sel_d;
		freq_sel_q <= freq_sel_d;
	end
end

always_comb begin
	rsp_o.ready  = 1'b1;
	rsp_o.rdata  = '0;
	rsp_o.error  = 1'b0;

	cc_sel_temp   = cc_sel_q;
	cc_sel_we     = 1'b0;
	fc_sel_temp	  = fc_sel_q;
	fc_sel_we  	  = 1'b0;
	div_sel_temp  = div_sel_q;
	div_sel_we    = 1'b0;
	freq_sel_temp = freq_sel_q;
	freq_sel_we   = 1'b0;

	if (req_i.valid) begin
		if (req_i.write) begin
			unique case (req_i.addr[12-1:0])
				12'h000: begin
					cc_sel_temp   = req_i.wdata[5:0];
					cc_sel_we     = 1'b1;
				end
				12'h008: begin
					fc_sel_temp   = req_i.wdata[5:0];
					fc_sel_we     = 1'b1;
				end
				12'h010: begin
					div_sel_temp  = req_i.wdata[2:0];
					div_sel_we    = 1'b1;
				end
				12'h018: begin
					freq_sel_temp = req_i.wdata[1:0];
					freq_sel_we   = 1'b1;
				end
				default: rsp_o.error = 1'b1;
			endcase
		end
		else begin
			unique case (req_i.addr[12-1:0])
				12'h000: rsp_o.rdata = {32'b0, 26'b0, cc_sel_q};
				12'h008: rsp_o.rdata = {32'b0, 26'b0, fc_sel_q};
				12'h010: rsp_o.rdata = {32'b0, 29'b0, div_sel_q};
				12'h018: rsp_o.rdata = {32'b0, 30'b0, freq_sel_q};
				default: rsp_o.error = 1'b1;
			endcase
		end
	end
end
endmodule
