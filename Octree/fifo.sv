module fifo_sync #(
    parameter       DATA_WIDTH                  = 8     ,   // 数据位宽
    parameter       DEPTH                       = 8     // FIFO 深度
) (
    input                                       clk                        ,
    input                                       rst_n                      ,
    input                                       wr_en                      ,// 写使能
    input                                       rd_en                      ,// 读使能
    input                [DATA_WIDTH-1: 0]      wdata                      ,// 写入数据
    output               [DATA_WIDTH-1: 0]      rdata                      ,// 读取数据
    output                                      empty                      ,// 读空标志
    output                                      full                        // 写满标志
);

    // FIFO 存储器
    reg                  [DATA_WIDTH-1: 0]      mem     [DEPTH-1:0]  ;
    reg                  [$clog2(DEPTH): 0]     wr_ptr                    ='0;// 写指针
    reg                  [$clog2(DEPTH): 0]     rd_ptr                    ='0;// 读指针
    reg                  [$clog2(DEPTH)-1: 0]   wr_addr,                  
                                                rd_addr;
    reg                  [DATA_WIDTH-1: 0]      rdata_reg                   ;

    assign      wr_addr              = wr_ptr[$clog2(DEPTH)-1:0];
    assign      rd_addr              = rd_ptr[$clog2(DEPTH)-1:0];

    // 写数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_en && !full) begin
            mem[wr_addr] <= wdata;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // 读数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_en && !empty) begin
            rdata_reg  <= mem[rd_addr];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // 计算空和满
    assign      empty                = (wr_ptr == rd_ptr);
    assign      full                 = (wr_ptr == {~rd_ptr[$clog2(DEPTH)], rd_ptr[$clog2(DEPTH)-1:0]});
    assign      rdata                = rdata_reg;

endmodule