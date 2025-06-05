// Author:          Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
// Description:     Behavioral model of the hyperbus delay

module hyperbus_delay_behav (
  input  logic in_i,
  input  logic [1:0] delay_i,
  output logic out_o
);

    always_ff @(in_i) begin
        case (delay_i)
            2'b00: out_o <= #1920  in_i;
            2'b01: out_o <= #3840  in_i;
            2'b10: out_o <= #7680  in_i;
            2'b11: out_o <= #15360 in_i;
        endcase
    end

endmodule