//------------------------------------------------------------------------------
// Description: PLL Configuration Registers
// Author:      Zhantong Zhu <zhu_20021122@stu.pku.edu.cn> [Peking University]
//------------------------------------------------------------------------------

module pll_regs #(
	parameter type reg_req_t = logic,
	parameter type reg_rsp_t = logic
)(
	input  logic        clk_i              ,
	input  logic        rstn_i             ,

    output logic        bypass_o           ,
    output logic [2:0]  sel_o              ,
    output logic [11:0] code_bp_o          ,

	// Bus Interface
	input  reg_req_t    req_i              ,
	output reg_rsp_t    rsp_o
);

logic [11:0]    code_bp_d, code_bp_q;
logic [2:0]     sel_d, sel_q;
logic           bypass_d, bypass_q;

assign bypass_o     = bypass_q;
assign sel_o        = sel_q;
assign code_bp_o    = code_bp_q;

always_ff @(posedge clk_i or negedge rstn_i) begin
	// Initialization for PLL
	if (~rstn_i) begin
        bypass_q    <=  '0;
        sel_q       <=  '0;
        code_bp_q   <=  '0;
	end
	else begin
        bypass_q    <=  bypass_d;
        sel_q       <=  sel_d;
        code_bp_q   <=  code_bp_d;
	end
end

always_comb begin
	rsp_o.ready  = 1'b1;
	rsp_o.rdata  = '0;
	rsp_o.error  = 1'b0;

    bypass_d     = bypass_q;
    sel_d        = sel_q;
    code_bp_d    = code_bp_q;

	if (req_i.valid) begin
		if (req_i.write) begin
			unique case (req_i.addr[12-1:0])
				12'h000: begin
                    bypass_d      = req_i.wdata[0];
				end
				12'h008: begin
					sel_d         = req_i.wdata[2:0];
				end
				12'h010: begin
					code_bp_d     = req_i.wdata[11:0];
				end
				default: rsp_o.error = 1'b1;
			endcase
		end
		else begin
			unique case (req_i.addr[12-1:0])
				12'h000: rsp_o.rdata = {32'b0, 31'b0, bypass_q};
				12'h008: rsp_o.rdata = {32'b0, 29'b0, sel_q};
				12'h010: rsp_o.rdata = {32'b0, 20'b0, code_bp_q};
				default: rsp_o.error = 1'b1;
			endcase
		end
	end
end
endmodule
