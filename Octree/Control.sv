`timescale 1ns / 1ps
module Control (
    input                               clk                        ,
    input                               rst_n                      ,
    input                [   1: 0]      ctrl                       ,// 指示当前需要octree完成的操作，包括：增、减anchor，还有遍历octree，以及中断当前节点的所有孩子
    output reg                          search_start               ,
    input                               search_done                ,
    output reg                          add_anchor                 ,
    output reg                          del_anchor                 ,
    input                               add_done                   ,
    input                               del_done                   ,

  //SRAM的选通信号：searcher，updater 两种选择
    output               [   1: 0]      mem_select                  
);

  //用于给sram的MUX指示接通那一个模块给sram sram_1_select与sram_2_select
    localparam      [   1: 0] NAN                         = 0     ,
                              SEARCHER                    = 1     ,
                              UPDATER                     = 2     ;
  //由外界告知的control 信号，告知octree应该做什么工作。即ctrl信号的取值。
    localparam      [   1: 0] WAIT                        = 0     , 
                              SEARCH                      = 1     ,
                              ADD                         = 2     ,
                              DEL                         = 3     ;

  typedef enum reg [1:0] {
    IDLE,
    SEARCHING,
    ADDING,
    DELETING
  } state_e;

  state_e state;

  always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
      search_start <= 1'b0;
      add_anchor   <= 1'b0;
      del_anchor   <= 1'b0;
      mem_select   <= NAN;
    end else begin
      case (state)
        IDLE: begin
          if (ctrl == SEARCH) begin
            state            <= SEARCHING;
            search_start <= 1'b1;
          end else if (ctrl == ADD) begin
            state            <= ADDING;
            add_anchor   <= 1'b1;
          end else if (ctrl == DEL) begin
            state            <= DELETING;
            del_anchor   <= 1'b1;
          end else begin
            state            <= IDLE;
            search_start <= 1'b0;
            add_anchor   <= 1'b0;
            del_anchor   <= 1'b0;
            mem_select   <= NAN;
          end
        end
        SEARCHING: begin
          if (search_done) begin
            state <= IDLE;
          end else begin
            search_start <= 1'b0;
            add_anchor   <= 1'b0;
            del_anchor   <= 1'b0;
            mem_select   <= SEARCHER;
          end
        end
        ADDING: begin
          if (add_done) begin
            state <= IDLE;
          end else begin
            search_start <= 1'b0;
            add_anchor   <= 1'b0;
            del_anchor   <= 1'b0;
            mem_select   <= UPDATER;
          end
        end
        DELETING: begin
          if (del_done) begin
            state <= IDLE;
          end else begin
            search_start <= 1'b0;
            add_anchor   <= 1'b0;
            del_anchor   <= 1'b0;
            mem_select   <= UPDATER;
          end
        end
        default: begin
          state        <= IDLE;
          search_start <= 1'b0;
          add_anchor   <= 1'b0;
          del_anchor   <= 1'b0;
          mem_select   <= NAN;
        end
      endcase
    end
  end

endmodule
