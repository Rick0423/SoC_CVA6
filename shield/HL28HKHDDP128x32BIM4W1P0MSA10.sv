module HL28HKHDDP128x32B1M4W1P0MSA10 (
    // 读端口 A：低半字（bit[31:0]）
    output logic [31:0] QA,
    input  logic [6:0]  ADRA,      // A 口地址，{1b’0, i_addr[5:0]}
    input  logic [31:0] DA,        // A 口写数据
    input  logic [31:0] WEMA,      // A 口写掩码
    input  logic        WEA,       // A 口写使能
    input  logic        MEA,       // A 口片选
    input  logic        CLKA,      // A 口时钟
    input  logic        TEST1A,
    input  logic        RMEA,
    input  logic [3:0]  RMA,
    input  logic        LS,

    // 读端口 B：高半字（bit[63:32]）
    output logic [31:0] QB,
    input  logic [6:0]  ADRB,      // B 口地址，{1b’1, i_addr[5:0]}
    input  logic [31:0] DB,        // B 口写数据
    input  logic [31:0] WEMB,      // B 口写掩码
    input  logic        WEB,       // B 口写使能
    input  logic        MEB,       // B 口片选
    input  logic        CLKB,      // B 口时钟
    input  logic        TEST1B,
    input  logic        RMEB,
    input  logic [3:0]  RMB
);

    // 128×32 位存储阵列
    logic [31:0] mem [0:127];

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
