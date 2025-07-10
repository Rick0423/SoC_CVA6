//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Date:            2025-07-10
// Design Name:     sram_macro
// Project Name:    VLSI-26 3DGS
// Description:     sram behaviour implementation 
//////////////////////////////////////////////////////////////////////////////////
module HL28HKHDDP1024x32BIM4W1P0MSA10 (
    // 读端口 A、B
    output logic [31:0] QA,
    output logic [31:0] QB,

    // 地址与写端口 A
    input  logic [9:0]  ADRA,     // A 口地址
    input  logic [31:0] DA,       // A 口写数据
    input  logic [31:0] WEMA,     // A 口写掩码
    input  logic        WEA,      // A 口写使能
    input  logic        MEA,      // A 口片选
    input  logic        CLKA,     // A 口时钟

    // 测试与模式控制 A
    input  logic        TEST1A,
    input  logic        RMEA,
    input  logic [3:0]  RMA,
    input  logic        LS,

    // 地址与写端口 B
    input  logic [9:0]  ADRB,     // B 口地址
    input  logic [31:0] DB,       // B 口写数据
    input  logic [31:0] WEMB,     // B 口写掩码
    input  logic        WEB,      // B 口写使能
    input  logic        MEB,      // B 口片选
    input  logic        CLKB,     // B 口时钟

    // 测试与模式控制 B
    input  logic        TEST1B,
    input  logic        RMEB,
    input  logic [3:0]  RMB
);

    // 1024×32 位存储阵列
    logic [31:0] mem [0:1023];

    //—— 端口 A ——//
    always_ff @(posedge CLKA) begin
        if (MEA) begin
            // 写：按位掩码
            if (WEA) begin
                for (int i = 0; i < 32; i++) begin
                    if (WEMA[i])
                        mem[ADRA][i] <= DA[i];
                end
            end
            // 读：同步输出
            QA <= mem[ADRA];
        end
    end

    //—— 端口 B ——//
    always_ff @(posedge CLKB) begin
        if (MEB) begin
            // 写：按位掩码
            if (WEB) begin
                for (int j = 0; j < 32; j++) begin
                    if (WEMB[j])
                        mem[ADRB][j] <= DB[j];
                end
            end
            // 读：同步输出
            QB <= mem[ADRB];
        end
    end

endmodule
