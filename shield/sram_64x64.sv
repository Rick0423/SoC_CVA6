module sram_64x64 (
    input  wire                         i_clk                      ,// 时钟
    input  wire                         i_cen                      ,// 使能（片选）
    input  wire                         i_wen                      ,// 写使能
    input  wire          [  63: 0]      i_bit_mask                 ,// 写掩码
    input  wire          [   5: 0]      i_addr                     ,// 地址
    input  wire          [  63: 0]      i_wdata                    ,// 写数据
    output wire          [  63: 0]      o_rdata                     // 读数据
);
    //split a 128x32 -> 64x64
    HL28HKHDDP128x32B1M4W1P0MSA10 sram_512B_inst (
        // 低半字（bit[31:0]）
        .QA     (o_rdata[31:0]),
        .ADRA   ({1'b0, i_addr}),
        .DA     (i_wdata[31:0]),
        .WEMA   (i_bit_mask[31:0]),
        .WEA    (i_wen),
        .MEA    (i_cen),
        .CLKA   (i_clk),
        .TEST1A (1'b1),
        .RMEA   (1'b1),
        .RMA    (4'b0011),
        .LS     (1'b0),
        // 高半字（bit[63:32]）
        .QB     (o_rdata[63:32]),
        .ADRB   ({1'b1, i_addr}),
        .DB     (i_wdata[63:32]),
        .WEMB   (i_bit_mask[63:32]),
        .WEB    (i_wen),
        .MEB    (i_cen),
        .CLKB   (i_clk),
        .TEST1B (1'b1),
        .RMEB   (1'b1),
        .RMB    (4'b0011)
    );

endmodule
