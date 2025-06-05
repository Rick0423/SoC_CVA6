// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Armin Berger <bergerar@ethz.ch>
// Stephan Keck <kecks@ethz.ch>

/// A Hyperbus differential clock output generator.
module hyperbus_clock_diff_out
(
    input  logic in_i,
    input  logic en_i, //high enable
    output logic out_o,
    output logic out_no
);

`ifdef SIM
    tc_clk_gating i_hyper_ck_gating (
        .clk_i     ( in_i  ),
        .en_i      ( en_i  ),
        .test_en_i ( 1'b0  ),
        .clk_o     ( out_o )
    );
`else
    CKLNQD20BWP7T30P140 i_hyper_ck_gating (
        .TE      ( 1'b0  ),
        .E       ( en_i  ),
        .CP      ( in_i  ),
        .Q       ( out_o )
    );
`endif

    tc_clk_inverter i_hyper_ck_no_inv (
        .clk_i ( out_o  ),
        .clk_o ( out_no )
    );

endmodule
