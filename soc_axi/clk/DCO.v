//`default_nettype none

// SET DONT_TOUCH ON ALL CELLS IN THIS MODULE

/*
// synopsys dc_script_begin
// set_dont_touch find("cell","*")
// synopsys dc_script_end
*/

module BUF_CHAIN10(Y, A);
output Y;
wire Y;
input A;
wire A;
wire [8:0] int1;
BUF buf1(.Y(int1[0]), .A(A));
BUF buf2(.Y(int1[1]), .A(int1[0]));
BUF buf3(.Y(int1[2]), .A(int1[1]));
BUF buf4(.Y(int1[3]), .A(int1[2]));
BUF buf5(.Y(int1[4]), .A(int1[3]));
BUF buf6(.Y(int1[5]), .A(int1[4]));
BUF buf7(.Y(int1[6]), .A(int1[5]));
BUF buf8(.Y(int1[7]), .A(int1[6]));
BUF buf9(.Y(int1[8]), .A(int1[7]));
BUF buf10(.Y(Y), .A(int1[8]));
endmodule

module CLK_BUF_CHAIN(Y, A);
output Y;
wire Y;
input A;
wire A;
wire [3:0] int1;
BUFFD1BWP7T30P140  buf1(.Z(int1[0]), .I(A));
BUFFD4BWP7T30P140 buf2(.Z(int1[1]), .I(int1[0]));
BUFFD8BWP7T30P140 buf3(.Z(int1[2]), .I(int1[1]));
BUFFD12BWP7T30P140 buf4(.Z(int1[3]), .I(int1[2]));
BUFFD20BWP7T30P140 buf5(.Z(Y), .I(int1[3]));
endmodule

module INV(Y, A);
output Y;
wire Y;
input A;
wire A;
INVD1BWP7T30P140 inv1(.ZN(Y), .I(A));
endmodule

module BUF(Y, A);
output Y;
wire Y;
input A;
wire A;
wire tmp;
INVD1BWP7T30P140 buf1(.ZN(tmp), .I(A));
INVD2BWP7T30P140 buf2(.ZN(Y), .I(tmp));
endmodule

module BUF16(Y, A);
output Y;
wire Y;
input A;
wire A;
//CLK_BUF_X4_CELL buf1(.Z(Y), .I(A));
BUFFD16BWP7T30P140 buf1(.Z(Y), .I(A));
endmodule

module MUX(Y, SEL, A, B);
output Y;
wire Y;
input A, B, SEL;
wire A, B, SEL;
//CLK_MUX_CELL mux2(.Z(Y), .S(SEL), .I0(A), .I1(B));
MUX2D4BWP7T30P140 mux2(.Z(Y), .S(SEL), .I0(A), .I1(B));
endmodule

//Programmable delay step: incrementing SEL by one adds in 1 BUF delay
module DELAY_STEP(Y, A);
output Y;
wire Y;
input A;
wire A;
BUF buf1(.Y(Y), .A(A));
endmodule


//Variable capacitance between muxed delay stages
//to fine-tune the DCO_RING period on the fly
//implemented using NAND2 gate input cap
//EN signal connected to the footer nmos gate (B), controling Cin(A).
//when the footer is on, Cin(A) is high; when the footer is off, Cin(B) is low.
module VARIABLE_CAP(EN, A);
input EN, A;
wire EN, A;
ND2D4BWP7T30P140 nand2_cell (.A2(EN), .A1(A), .ZN());
endmodule

//SEL has 7 control bits
//Programmable delay step: incrementing SEL by one adds in 1 BUF delay
//FixedBufDly = 0 stages of BUF delay
module DCO_RING(EN, DCLK, SEL, FC_SEL);
input EN;
wire EN;
input [5:0] SEL;
wire [5:0] SEL;
input [5:0] FC_SEL;
wire [5:0] FC_SEL;
output DCLK;
wire DCLK;
wire [6:0] A;
wire [6:0] A_tmp;
wire [5:0] B;
wire [1:1] int1;
wire [3:1] int2;
wire [7:1] int3;
wire [15:1] int4;
wire [31:1] int5;

//Added variable cap control signals to fine-tune the load caps (NAND2 Cin(A))
VARIABLE_CAP XVARIABLE_CAP0_1 (.EN(FC_SEL[0]), .A(A[0]));

VARIABLE_CAP XVARIABLE_CAP1_1 (.EN(FC_SEL[1]), .A(A[0]));
VARIABLE_CAP XVARIABLE_CAP1_2 (.EN(FC_SEL[1]), .A(A[0]));

VARIABLE_CAP XVARIABLE_CAP2_1 (.EN(FC_SEL[2]), .A(A[1]));
VARIABLE_CAP XVARIABLE_CAP2_2 (.EN(FC_SEL[2]), .A(A[1]));
VARIABLE_CAP XVARIABLE_CAP2_3 (.EN(FC_SEL[2]), .A(A[1]));

VARIABLE_CAP XVARIABLE_CAP3_1 (.EN(FC_SEL[3]), .A(A[2]));
VARIABLE_CAP XVARIABLE_CAP3_2 (.EN(FC_SEL[3]), .A(A[2]));
VARIABLE_CAP XVARIABLE_CAP3_3 (.EN(FC_SEL[3]), .A(A[2]));
VARIABLE_CAP XVARIABLE_CAP3_4 (.EN(FC_SEL[3]), .A(A[2]));

VARIABLE_CAP XVARIABLE_CAP4_1 (.EN(FC_SEL[4]), .A(A[3]));
VARIABLE_CAP XVARIABLE_CAP4_2 (.EN(FC_SEL[4]), .A(A[3]));
VARIABLE_CAP XVARIABLE_CAP4_3 (.EN(FC_SEL[4]), .A(A[3]));
VARIABLE_CAP XVARIABLE_CAP4_4 (.EN(FC_SEL[4]), .A(A[3]));
VARIABLE_CAP XVARIABLE_CAP4_5 (.EN(FC_SEL[4]), .A(A[4]));

VARIABLE_CAP XVARIABLE_CAP5_1 (.EN(FC_SEL[5]), .A(A[4]));
VARIABLE_CAP XVARIABLE_CAP5_2 (.EN(FC_SEL[5]), .A(A[4]));
VARIABLE_CAP XVARIABLE_CAP5_3 (.EN(FC_SEL[5]), .A(A[4]));
VARIABLE_CAP XVARIABLE_CAP5_4 (.EN(FC_SEL[5]), .A(A[5]));
VARIABLE_CAP XVARIABLE_CAP5_5 (.EN(FC_SEL[5]), .A(A[5]));
VARIABLE_CAP XVARIABLE_CAP5_6 (.EN(FC_SEL[5]), .A(A[5]));

//instantiate an array of 6 varaible_cap, loaded on each mux output node
//each node has #6.

//CLK_NAND_CELL nanden(.ZN(A[0]), .A1(DCLK), .A2(EN));
ND2D2BWP7T30P140 nanden(.ZN(A_tmp[0]), .A1(A[6]), .A2(EN));
BUF buf_a0(.Y(A[0]), .A(A_tmp[0]));
BUF buffers(.Y(DCLK), .A(A[6]));
MUX mux0(.Y(A_tmp[1]), .SEL(SEL[0]), .A(A[0]), .B(B[0]));
BUF buf_a1(.Y(A[1]), .A(A_tmp[1]));
DELAY_STEP buf0_0(.Y(B[0]), .A(A[0]));
MUX mux1(.Y(A_tmp[2]), .SEL(SEL[1]), .A(A[1]), .B(B[1]));
BUF buf_a2(.Y(A[2]), .A(A_tmp[2]));
DELAY_STEP buf1_0(.Y(B[1]), .A(A[1]));
MUX mux2(.Y(A_tmp[3]), .SEL(SEL[2]), .A(A[2]), .B(B[2]));
BUF buf_a3(.Y(A[3]), .A(A_tmp[3]));
DELAY_STEP buf2_0(.Y(int2[1]), .A(A[2]));
DELAY_STEP buf2_1(.Y(B[2]), .A(int2[1]));
MUX mux3(.Y(A_tmp[4]), .SEL(SEL[3]), .A(A[3]), .B(B[3]));
BUF buf_a4(.Y(A[4]), .A(A_tmp[4]));
DELAY_STEP buf3_0(.Y(int3[1]), .A(A[3]));
DELAY_STEP buf3_1(.Y(int3[2]), .A(int3[1]));
DELAY_STEP buf3_2(.Y(int3[3]), .A(int3[2]));
DELAY_STEP buf3_3(.Y(B[3]), .A(int3[3]));
MUX mux4(.Y(A_tmp[5]), .SEL(SEL[4]), .A(A[4]), .B(B[4]));
BUF buf_a5(.Y(A[5]), .A(A_tmp[5]));
DELAY_STEP buf4_0(.Y(int4[1]), .A(A[4]));
DELAY_STEP buf4_1(.Y(int4[2]), .A(int4[1]));
DELAY_STEP buf4_2(.Y(int4[3]), .A(int4[2]));
DELAY_STEP buf4_3(.Y(int4[4]), .A(int4[3]));
DELAY_STEP buf4_4(.Y(int4[5]), .A(int4[4]));
DELAY_STEP buf4_5(.Y(int4[6]), .A(int4[5]));
DELAY_STEP buf4_6(.Y(int4[7]), .A(int4[6]));
DELAY_STEP buf4_7(.Y(B[4]), .A(int4[7]));
MUX mux5(.Y(A_tmp[6]), .SEL(SEL[5]), .A(A[5]), .B(B[5]));
BUF buf_a6(.Y(A[6]), .A(A_tmp[6]));
DELAY_STEP buf5_0(.Y(int5[1]), .A(A[5]));
DELAY_STEP buf5_1(.Y(int5[2]), .A(int5[1]));
DELAY_STEP buf5_2(.Y(int5[3]), .A(int5[2]));
DELAY_STEP buf5_3(.Y(int5[4]), .A(int5[3]));
DELAY_STEP buf5_4(.Y(int5[5]), .A(int5[4]));
DELAY_STEP buf5_5(.Y(int5[6]), .A(int5[5]));
DELAY_STEP buf5_6(.Y(int5[7]), .A(int5[6]));
DELAY_STEP buf5_7(.Y(int5[8]), .A(int5[7]));
DELAY_STEP buf5_8(.Y(int5[9]), .A(int5[8]));
DELAY_STEP buf5_9(.Y(int5[10]), .A(int5[9]));
DELAY_STEP buf5_10(.Y(int5[11]), .A(int5[10]));
DELAY_STEP buf5_11(.Y(int5[12]), .A(int5[11]));
DELAY_STEP buf5_12(.Y(int5[13]), .A(int5[12]));
DELAY_STEP buf5_13(.Y(int5[14]), .A(int5[13]));
DELAY_STEP buf5_14(.Y(int5[15]), .A(int5[14]));
DELAY_STEP buf5_15(.Y(B[5]), .A(int5[15]));

endmodule


module CLK_DIVIDER(CLK_IN, CLK_OUT, FRSTN);
input CLK_IN;
wire CLK_IN;
output CLK_OUT;
wire CLK_OUT;
input FRSTN;
wire FRSTN;
wire CLK_DIV_D;
wire CLK_DIV_Q, CLK_DIV_QN;
//DFF Truth table
//  SETN    CLK    D    |    QN
//   0       x     x    |    0 
//   1      _/-    0    |    1
//   1      _/-    1    |    0
//   1       0     x    |    QN
//   1       1     x    |    QN
//
//DFF_CELL DFFSQN(.CLK(CLK_IN), .D(CLK_DIV_D), .QN(CLK_DIV_QN), .SETN(FRSTN));
DFKCNQD2BWP7T30P140 DFFSQN(.CP(CLK_IN), .D(CLK_DIV_D), .Q(CLK_DIV_Q), .CN(FRSTN));
INVD1BWP7T30P140 inv1(.ZN(CLK_DIV_QN), .I(CLK_DIV_Q));

BUF buf_loop(.Y(CLK_DIV_D), .A(CLK_DIV_QN));
BUF bufdiv(.Y(CLK_OUT), .A(CLK_DIV_QN));
endmodule

module MX_CLK_DIVIDER(CLK_IN, CLK_OUT, SEL, FRSTN);
input CLK_IN;
wire CLK_IN;
output CLK_OUT;
wire CLK_OUT;
input [2:0] SEL;
wire [2:0] SEL;
input FRSTN;
wire FRSTN;
wire [0:7] X0;
wire CLK_DIV;
BUF buf0(.Y(X0[0]), .A(CLK_IN));
CLK_DIVIDER DIV0 (.CLK_IN(X0[0]), .CLK_OUT(X0[1]), .FRSTN(FRSTN));
CLK_DIVIDER DIV1 (.CLK_IN(X0[1]), .CLK_OUT(X0[2]), .FRSTN(FRSTN));
CLK_DIVIDER DIV2 (.CLK_IN(X0[2]), .CLK_OUT(X0[3]), .FRSTN(FRSTN));
CLK_DIVIDER DIV3 (.CLK_IN(X0[3]), .CLK_OUT(X0[4]), .FRSTN(FRSTN));
CLK_DIVIDER DIV4 (.CLK_IN(X0[4]), .CLK_OUT(X0[5]), .FRSTN(FRSTN));
CLK_DIVIDER DIV5 (.CLK_IN(X0[5]), .CLK_OUT(X0[6]), .FRSTN(FRSTN));
CLK_DIVIDER DIV6 (.CLK_IN(X0[6]), .CLK_OUT(X0[7]), .FRSTN(FRSTN));
wire [3:0] X1;
wire [1:0] X2;
MUX mux10(.A(X0[0]), .B(X0[1]), .SEL(SEL[0]), .Y(X1[0]));
MUX mux11(.A(X0[2]), .B(X0[3]), .SEL(SEL[0]), .Y(X1[1]));
MUX mux12(.A(X0[4]), .B(X0[5]), .SEL(SEL[0]), .Y(X1[2]));
MUX mux13(.A(X0[6]), .B(X0[7]), .SEL(SEL[0]), .Y(X1[3]));
MUX mux20(.A(X1[0]), .B(X1[1]), .SEL(SEL[1]), .Y(X2[0]));
MUX mux21(.A(X1[2]), .B(X1[3]), .SEL(SEL[1]), .Y(X2[1]));
MUX mux30(.A(X2[0]), .B(X2[1]), .SEL(SEL[2]), .Y(CLK_DIV));
BUF bufmx(.Y(CLK_OUT), .A(CLK_DIV));
endmodule

module MX_CLK_DIVIDER_SMALL(CLK_IN, CLK_OUT, SEL, FRSTN); //SEL: 00:CLK_IN, 01:/2, 11:/4
input CLK_IN;
wire CLK_IN;
output CLK_OUT;
wire CLK_OUT;
input [1:0] SEL;
wire [1:0] SEL;
input FRSTN;
wire FRSTN;
wire [0:3] X0;
wire CLK_DIV;
BUF buf0(.Y(X0[0]), .A(CLK_IN));
CLK_DIVIDER DIV0 (.CLK_IN(X0[0]), .CLK_OUT(X0[1]), .FRSTN(FRSTN));
CLK_DIVIDER DIV1 (.CLK_IN(X0[1]), .CLK_OUT(X0[2]), .FRSTN(FRSTN));
MUX mux0(.A(X0[0]), .B(X0[3]), .SEL(SEL[0]), .Y(CLK_DIV));
MUX mux1(.A(X0[1]), .B(X0[2]), .SEL(SEL[1]), .Y(X0[3]));
BUF bufmx(.Y(CLK_OUT), .A(CLK_DIV));
endmodule

module DCO(EN,CC_SEL,FC_SEL,EXT_CLK,CLK_SEL,DIV_SEL,FREQ_SEL,CLK,CLK_DIV,RSTN); // cadence black_box
input RSTN;
wire RSTN;
input EN;
wire EN;
input EXT_CLK, CLK_SEL;
wire EXT_CLK, CLK_SEL;
input [5:0] CC_SEL;
wire [5:0] CC_SEL;
input [2:0] DIV_SEL;
wire [2:0] DIV_SEL;
input [1:0] FREQ_SEL;
wire [1:0] FREQ_SEL;
output CLK;
wire CLK;
output CLK_DIV;
wire CLK_DIV;
//fine-tune inter-mux cap load
// TODO only using 6:1, keeping it as 6:0 for compatibility (LSB floating)
input [5:0] FC_SEL;
wire [5:0] FC_SEL;

wire EN_I, RSTN_I;
wire [5:0] CC_SEL_I, FC_SEL_I;
wire [2:0] DIV_SEL_I;
wire [1:0] FREQ_SEL_I;
wire RING_OUT, DIV_CLK_OUT;
wire EXT_CLK_I, CLK_SEL_I;
wire CLK_SELECT;
wire CLK_I;

BUF bufen(.Y(EN_I), .A(EN));
BUF bufrstn(.Y(RSTN_I), .A(RSTN));
BUF bufdcosel_0(.Y(CC_SEL_I[0]), .A(CC_SEL[0]));
BUF bufdcosel_1(.Y(CC_SEL_I[1]), .A(CC_SEL[1]));
BUF bufdcosel_2(.Y(CC_SEL_I[2]), .A(CC_SEL[2]));
BUF bufdcosel_3(.Y(CC_SEL_I[3]), .A(CC_SEL[3]));
BUF bufdcosel_4(.Y(CC_SEL_I[4]), .A(CC_SEL[4]));
BUF bufdcosel_5(.Y(CC_SEL_I[5]), .A(CC_SEL[5]));
BUF bufdfine_0(.Y(FC_SEL_I[0]), .A(FC_SEL[0]));
BUF bufdfine_1(.Y(FC_SEL_I[1]), .A(FC_SEL[1]));
BUF bufdfine_2(.Y(FC_SEL_I[2]), .A(FC_SEL[2]));
BUF bufdfine_3(.Y(FC_SEL_I[3]), .A(FC_SEL[3]));
BUF bufdfine_4(.Y(FC_SEL_I[4]), .A(FC_SEL[4]));
BUF bufdfine_5(.Y(FC_SEL_I[5]), .A(FC_SEL[5]));
BUF bufdivsel_0(.Y(DIV_SEL_I[0]), .A(DIV_SEL[0]));
BUF bufdivsel_1(.Y(DIV_SEL_I[1]), .A(DIV_SEL[1]));
BUF bufdivsel_2(.Y(DIV_SEL_I[2]), .A(DIV_SEL[2]));
BUF bufextclk(.Y(EXT_CLK_I), .A(EXT_CLK));
BUF bufclksel(.Y(CLK_SEL_I), .A(CLK_SEL));
BUF buffreqsel_0(.Y(FREQ_SEL_I[0]), .A(FREQ_SEL[0]));
BUF buffreqsel_1(.Y(FREQ_SEL_I[1]), .A(FREQ_SEL[1]));

// DCO
DCO_RING DCO_CORE(.EN(EN_I), .SEL(CC_SEL_I), .DCLK(RING_OUT), .FC_SEL(FC_SEL_I));

MUX mux_clk(.A(RING_OUT), .B(EXT_CLK_I), .SEL(CLK_SEL_I), .Y(CLK_SELECT));

// Clock Divider, for testing purpose
MX_CLK_DIVIDER DIVIDER_TEST(.CLK_IN(CLK_SELECT), .CLK_OUT(DIV_CLK_OUT), .SEL(DIV_SEL_I), .FRSTN(RSTN_I));

MX_CLK_DIVIDER_SMALL DIVIDER_CLK(.CLK_IN(CLK_SELECT), .CLK_OUT(CLK_I), .SEL(FREQ_SEL_I), .FRSTN(RSTN_I));

CLK_BUF_CHAIN bufdclk(.Y(CLK), .A(CLK_I));
CLK_BUF_CHAIN bufdivclk(.Y(CLK_DIV), .A(DIV_CLK_OUT));

endmodule

//`default_nettype wire

