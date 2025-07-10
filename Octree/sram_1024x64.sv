//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-10
// Design Name:     sram_1024x64
// Project Name:    VLSI-26 3DGS
// Description:     sram for local_mem and in_out_mem
//////////////////////////////////////////////////////////////////////////////////
module sram_1024x64 (
    input  wire                         i_clk                      ,// 时钟
    input  wire                         i_cen                      ,// 使能（片选）
    input  wire                         i_wen                      ,// 写使能
    input  wire          [  63: 0]      i_bit_mask                 ,// 写掩码
    input  wire          [   9: 0]      i_addr                     ,// 地址
    input  wire          [  63: 0]      i_wdata                    ,// 写数据
    output wire          [  63: 0]      o_rdata                     // 读数据
);

    genvar i;
    generate
        // 将 1024×64 拆分成 2×(1024×32) 的小块
        for (i = 0; i < 2; i = i + 1) begin : cache_gen
            HL28HKHDDP1024x32B1M4W1P0MSA10 sram_4KB_inst (
                // 读端口 A，32 位
                .QA     (o_rdata[i*32 + 31 -: 32]),
                .QB     (),                     // 端口 B 不使用

                // 地址与写端口 A
                .ADRA   (i_addr),
                .DA     (i_wdata[i*32 + 31 -: 32]),
                .WEMA   (i_bit_mask[i*32 + 31 -: 32]),
                .WEA    (i_wen),
                .MEA    (i_cen),
                .CLKA   (i_clk),

                // 测试与模式控制
                .TEST1A (1'b1),
                .RMEA   (1'b1),
                .RMA    (4'b0011),
                .LS     (1'b0),

                // 端口 B 全部悬空/常量
                .ADRB   (10'b0),
                .DB     (32'b0),
                .WEMB   (32'b0),
                .WEB    (1'b0),
                .MEB    (1'b0),
                .CLKB   (i_clk),
                .TEST1B (1'b1),
                .RMEB   (1'b1),
                .RMB    (4'b0011)
            );
        end
    endgenerate

endmodule
