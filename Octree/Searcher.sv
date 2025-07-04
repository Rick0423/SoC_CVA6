`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Date:            2025-07-04
// Design Name:     Octree_wrapper
// Project Name:    VLSI-26 3DGS
// Description:     Searcher for rendering 
//////////////////////////////////////////////////////////////////////////////////
module Searcher #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH               = 10    ,
    parameter       TREE_START_ADDR             = 0     ,
    parameter       LOD_START_ADDR              = 500   ,
    parameter       FEATURE_START_ADDR          = 1200  ,
    parameter       ENCODE_ADDR_WIDTH           = 3 * TREE_LEVEL + $clog2(TREE_LEVEL),
    parameter       FIFO_DATA_WIDTH             = ENCODE_ADDR_WIDTH + 3+1+3*8, //+1原因在于0-8需要4bit数据来表示
    parameter       FIFO_DEPTH_1                = ENCODE_ADDR_WIDTH + 10,
    parameter       FIFO_DEPTH_2                = ENCODE_ADDR_WIDTH + 10
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //控制信号，用于与controler交互 
    input                               search_start               ,
    output reg                          search_done                ,
  //用于和主存连接的mem接口
    output                              mem_sram_CEN               ,
    output               [  63: 0]      mem_sram_A                 ,
    output               [  63: 0]      mem_sram_D                 ,
    output                              mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //CSR信号
    input             [2:0][15: 0]      cam_pos                    ,
    input                [  15: 0]      dist_max                   ,
    input                [  15: 0]      s                          ,
  //输出的feature
    output               [  63: 0]      feature_out                ,
    output                              out_ready                  ,
  //当前主存中存储的八叉树的总量
    input                [   3: 0]      tree_num                    
);
  //针对SRAM接口进行多路选通
    localparam      [   1: 0] SRAM_LOD                    = 0     , 
                              SRAM_SEARCH                 = 1     ;

  //状态机的状态
    localparam      [   1: 0] IDLE                        = 0     , 
                              LOD                         = 1     ,
                              TREE_SEARCH                 = 2     ,
                              DONE                        = 3     ;

  //用于可能的计数器
    reg                  [   3: 0]      tree_cnt                    ;

  //主存接口
    wire                                lod_sram_CEN                ;
    wire                 [  63: 0]      lod_sram_A                  ;
    wire                 [  63: 0]      lod_sram_D                  ;
    wire                                lod_sram_GWEN               ;
    wire                 [  63: 0]      lod_sram_Q                  ;
    wire                                search_sram_CEN             ;
    wire                 [  63: 0]      search_sram_A               ;
    wire                 [  63: 0]      search_sram_D               ;
    wire                                search_sram_GWEN            ;
    wire                 [  63: 0]      search_sram_Q               ;

  //用于和lod计算部分的接口
    wire         [TREE_LEVEL-1: 0]      lod_active                  ;
    wire                                lod_ready                   ;
    reg                                 cal_lod                     ;

  //用于和tree search链接的端口
    wire                                tree_search_done            ;
    reg                                 tree_search_start           ;

  //用于Searcher顶层的一些状态指示
    reg                  [   1: 0]      mem_select                  ;
    reg                  [   1: 0]      searcher_state              ;
    reg          [TREE_LEVEL-1: 0]      lod_active_reg              ;

    assign      mem_sram_CEN         = (mem_select == SRAM_LOD)    ? lod_sram_CEN    :
                                       (mem_select == SRAM_SEARCH) ? search_sram_CEN :  1'b1;
    assign      mem_sram_A           = (mem_select == SRAM_LOD)    ? lod_sram_A      :
                                       (mem_select == SRAM_SEARCH) ? search_sram_A   :  '0;
    assign      mem_sram_D           = (mem_select == SRAM_LOD)    ? lod_sram_D      :
                                       (mem_select == SRAM_SEARCH) ? search_sram_D   :  '0;
    assign      mem_sram_GWEN        = (mem_select == SRAM_LOD)    ? lod_sram_GWEN   :
                                       (mem_select == SRAM_SEARCH) ? search_sram_GWEN:  1'b1;
    assign      search_sram_Q        = (mem_select == SRAM_SEARCH) ? mem_sram_Q      :  '0;
    assign      lod_sram_Q           = (mem_select == SRAM_LOD)    ? mem_sram_Q      :  '0;


  //用于两个模块流程的状态机
  always_ff @(posedge clk or negedge rst_n) begin : state_machine_for_searcher
    if (rst_n == 0) begin
      mem_select <= SRAM_LOD;
      searcher_state <= IDLE;
      tree_cnt   <= 0;
      cal_lod    <= 0;
      search_done <= 0;
      tree_search_start <= 0;
    end else begin
      case (searcher_state)
        IDLE: begin
          mem_select <= SRAM_LOD;
          tree_cnt   <= 0;
          cal_lod    <= 0;
          search_done <= 0;
          if (search_start) begin
            searcher_state <= LOD;
          end
        end
        LOD: begin
          if (lod_ready) begin
            searcher_state <= TREE_SEARCH;
            mem_select     <= SRAM_SEARCH;
            tree_search_start <= 1;
            cal_lod        <= 0;
            lod_active_reg <= lod_active;
          end else begin
            cal_lod    <= 1;
            mem_select <= SRAM_LOD;
          end
        end
        TREE_SEARCH: begin
          if (tree_search_done) begin
            tree_search_start <= 1;
            if (tree_cnt == tree_num - 1) begin
              search_done    <= 1;
              searcher_state <= IDLE;
            end else begin
              tree_cnt       <= tree_cnt + 1;
              searcher_state <= LOD;
            end
          end else begin
            tree_search_start <= 0;
          end
        end
        default: begin
          searcher_state <= IDLE;
          mem_select     <= SRAM_LOD;
          tree_cnt       <= 0;
          cal_lod        <= 0;
        end
      endcase
    end
  end

  lod_compute #(
    .LOD_START_ADDR              (LOD_START_ADDR            ) 
  ) u_lod_compute (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .cal_lod                     (cal_lod                   ),
    .lod_ready                   (lod_ready                 ),
    .mem_sram_CEN                (lod_sram_CEN              ),
    .mem_sram_A                  (lod_sram_A                ),
    .mem_sram_D                  (lod_sram_D                ),
    .mem_sram_GWEN               (lod_sram_GWEN             ),
    .mem_sram_Q                  (lod_sram_Q                ),
    .cam_pos                     (cam_pos                   ),
    .current_tree_count          ({12'd0,tree_cnt}          ),
    .lod_active                  (lod_active                ),
    .dist_max                    (dist_max                  ),
    .s                           (s                         ) 
  );

  tree_search  #(
    .FEATURE_LENGTH               (FEATURE_LENGTH             ),
    .TREE_START_ADDR             (TREE_START_ADDR           ),
    .FEATURE_START_ADDR          (FEATURE_START_ADDR        ),
    .ENCODE_ADDR_WIDTH           (ENCODE_ADDR_WIDTH         ),
    .FIFO_DATA_WIDTH             (FIFO_DATA_WIDTH           ),
    .FIFO_DEPTH_1                (FIFO_DEPTH_1              ),
    .FIFO_DEPTH_2                (FIFO_DEPTH_2              ) 
  ) u_tree_search (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .tree_search_start           (tree_search_start         ),
    .tree_search_done            (tree_search_done          ),
    .mem_sram_CEN                (search_sram_CEN           ),
    .mem_sram_A                  (search_sram_A             ),
    .mem_sram_D                  (search_sram_D             ),
    .mem_sram_GWEN               (search_sram_GWEN          ),
    .mem_sram_Q                  (search_sram_Q             ),
    .feature_out                 (feature_out               ),
    .out_ready                   (out_ready                 ),
    .tree_cnt                    (tree_cnt                  ),
    .lod_active                  (lod_active_reg            ) 
  );
  
  
endmodule

module tree_search #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH               = 10    ,
    parameter       TREE_START_ADDR             = 0     ,
    parameter       FEATURE_START_ADDR          = 400   ,
    parameter       ENCODE_ADDR_WIDTH           = 3 * TREE_LEVEL + $clog2(TREE_LEVEL),
    parameter       FIFO_DATA_WIDTH             = ENCODE_ADDR_WIDTH + 3+1+3*8, //+1原因在与0-8需要4bit数据来表示
    parameter       FIFO_DEPTH_1                = ENCODE_ADDR_WIDTH + 10,
    parameter       FIFO_DEPTH_2                = ENCODE_ADDR_WIDTH + 10
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //控制信号
    input                               tree_search_start          ,
    output reg                          tree_search_done           ,
    input                [   3: 0]      tree_cnt                   ,
    input        [TREE_LEVEL-1: 0]      lod_active                 ,
  //主存接口
    output reg                          mem_sram_CEN               ,
    output               [  63: 0]      mem_sram_A                 ,
    output reg           [  63: 0]      mem_sram_D                 ,
    output reg                          mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //输出接口（连PE）
    output               [  63: 0]      feature_out                ,
    output                              out_ready                   
);
    localparam      [   1: 0] IDLE                        = 0     , 
                              SEARCH                      = 1     ,
                              OUT                         = 2     ,
                              DONE                        = 3     ;
    localparam      [   2: 0] FIFO_IDLE                   = 0     ,
                              FIFO_SEARCH                 = 1     ,
                              FIFO_OUTPUT                 = 2     ,
                              FIFO_SEARCH_THIS_ANCHOR     = 3     ,
                              FIFO_READY_OUT              = 4     ,
                              FIFO_OUTPUT_THIS_ANCHOR     = 5     ,
                              FIFO_STALL_1_C              = 6     ;

    localparam    [4:0][63: 0]ADDR_VARY                   = {64'd74, 64'd10, 64'd2, 64'd1, 64'd0};
    localparam       int      PRIMES[4:0]                 = {2099719, 3867465, 807545, 2654435, 1};// 质数数组，增强哈希随机性
    

  //控制信号、计数器、状态机
    reg                  [   3: 0]      fifo_cnt                    ,
                                        in_anchor_cnt               ;
    reg                  [   1: 0]      tree_state                  ;
    reg                  [   2: 0]      fifo_state                  ;
    reg                                 outing_done                 ;
    reg                                 searching_done              ;
    reg                                 first                       ;

  //输入到FIFO中保存的anchor原码地址
    reg   [ENCODE_ADDR_WIDTH-1: 0]      w_fifo_pos_encode           ;
  //从64bit中选出关心的16bit,4选1。
    reg                  [   1: 0]      anchor_interested           ;

  //解算的组合逻辑，根据从SRAM中读上来的数据，生成ready to search的数据，写入FIFO中
    reg                  [   7: 0]      self_data                   ;
    reg                  [   7: 0]      child_data                  ;
    reg                [7:0][2: 0]      self_ones_pos               ;
    reg                  [   3: 0]      self_ones_count             ;
    reg                [7:0][2: 0]      child_ones_pos              ;
    reg                  [   3: 0]      child_ones_count            ;

  //用于标识流水线中的数据是否有效。
    reg                                 offset_level_valid          ;
    reg                                 mem_read_data_valid         ;//访存拿到的数据是否有效
    reg                                 mem_read_data_valid_pre     ;
    reg                                 write_fifo_data_valid       ;//准备写进fifo的数据是否有效
  

  //FIFO的接口信号
    reg                                 fifo_1_wr_en                ;
    reg                                 fifo_1_rd_en                ;
    reg                                 fifo_1_empty                ;
    reg                                 fifo_1_full                 ;
    reg     [FIFO_DATA_WIDTH-1: 0]      fifo_1_wdata                ;
    reg     [FIFO_DATA_WIDTH-1: 0]      fifo_1_rdata                ;

    reg                                 fifo_2_wr_en                ;
    reg                                 fifo_2_rd_en                ;
    reg                                 fifo_2_empty                ;
    reg                                 fifo_2_full                 ;
    reg     [FIFO_DATA_WIDTH-1: 0]      fifo_2_wdata                ;
    reg     [FIFO_DATA_WIDTH-1: 0]      fifo_2_rdata                ;

  //从fifo中读出的数据中的第三部分，标识当前的fifo读出信号中有多少个有效的anchor，
    reg                  [   3: 0]      r_fifo_1_anchor_num         ;
    reg                  [   3: 0]      r_fifo_2_anchor_num         ;

  //实际地址计算过程中的使用的数据，方便debug地址线是否正确。
    reg  [$clog2(TREE_LEVEL)-1: 0]      level                       ;
    reg                  [ 3-1: 0]      offset[4:0]                 ;
  //加_ 表示是组合逻辑信号，组合路径太长，插入寄存器，level和offset
    reg                  [  63: 0]      address_part_               ;
    reg                  [  63: 0]      actual_address              ;
    reg                  [  63: 0]      address_for_sram            ;
    reg   [ENCODE_ADDR_WIDTH-1: 0]      mem_posencode               ;
    reg                [7:0][2: 0]      rdata_1_slice               ;
    reg                [7:0][2: 0]      rdata_2_slice               ;

  // Direct mapping calculation
    reg                  [  63: 0]      hash_addr                   ;
  // Fast hash calculation

  //总的状态机
  always_ff @(posedge clk or negedge rst_n) begin : state_machin
    if (rst_n == 0) begin
      tree_state       <= IDLE;
      tree_search_done <= 0;
    end else begin
      case (tree_state)
        IDLE: begin
          if (tree_search_start) begin
            tree_state <= SEARCH;
          end else begin
            tree_search_done <= 0;
          end
        end
        SEARCH: begin
          if(searching_done) begin
            tree_state <= OUT;
          end
        end
        OUT: begin
          if(outing_done) begin
            tree_state <= DONE;
          end
        end
        DONE: begin
          tree_search_done <= 1;
          tree_state       <= IDLE;
        end
      endcase
    end
  end

  //从主存中读取数据，写入child_data、self_data中以便之后的处理
  always_ff @( posedge clk or negedge rst_n ) begin : get_intersted_data
    if(rst_n == 0) begin
      self_data <= 0;
      child_data <= 0;
    end else if(mem_read_data_valid) begin
      for (int i = 0; i < 8; i++) begin : bit_separation
            child_data[i] <= mem_sram_Q[anchor_interested*8*2+2*i]; // 提取偶数位
            self_data[i]  <= mem_sram_Q[anchor_interested*8*2+2*i + 1];// 提取奇数位
        end
    end
  end

  //从输入拿到的数据，根据组合逻辑，生成要写入输出fifo的anchor数据。
  int i, j;
  always_comb begin : produce_ready_to_read_data_self
    self_ones_count = 0;
    // 初始化所有位置为0
    for (int i = 0; i < 8; i = i + 1) self_ones_pos[i] = 0;
    j = 0;
    // 遍历每一位，如果为1则将位下标存入 ones_pos 数组中
    for (i = 0; i < 8; i = i + 1) begin
      if (self_data[i]) begin
        self_ones_pos[j] = i[2:0];                                  // i 的值（只取低3位）即为位序
        j                = j + 1;
      end
    end
    self_ones_count = j[3:0];
  end

  //从输入拿到的数据，根据组合逻辑，生成要写入搜索fifo的anchor数据。
  int u, o;
  always_comb begin : produce_ready_to_read_data_child
    child_ones_count = 0;
    // 初始化所有位置为0
    for (int u = 0; u < 8; u = u + 1) child_ones_pos[u] = 0;
    o = 0;
    // 遍历每一位，如果为1则将位下标存入 ones_pos 数组中
    for (u = 0; u < 8; u = u + 1) begin
      if (child_data[u]) begin
        child_ones_pos[o] = u[2:0];                                 // i 的值（只取低3位）即为位序
        o                 = o + 1;
      end
    end
    child_ones_count = o[3:0];
  end

  //写入FIFO的逻辑
  always_ff @(posedge clk or negedge rst_n) begin : FIFO_write_logic
    if (rst_n == 0) begin
      fifo_1_wr_en <= 0;
      fifo_2_wr_en <= 0;
      fifo_1_wdata <= 0;
      fifo_2_wdata <= 0;
    end else begin
      if (write_fifo_data_valid & (tree_state == SEARCH)) begin     // 只有在搜索阶段需要写入FIFO  
        if((child_ones_count != 0) && lod_active[w_fifo_pos_encode[ENCODE_ADDR_WIDTH-1 -:2]]) begin
          fifo_1_wr_en <= 1;
          fifo_1_wdata <= {w_fifo_pos_encode, child_ones_pos, child_ones_count};
        end else begin
          fifo_1_wr_en <= 0;
        end
        if((self_ones_count != 0) && lod_active[w_fifo_pos_encode[ENCODE_ADDR_WIDTH-1 -:2]]) begin
          fifo_2_wr_en <= 1;
          fifo_2_wdata <= {w_fifo_pos_encode, self_ones_pos, self_ones_count};
        end else begin
          fifo_2_wr_en <= 0;
        end
      end else begin
        fifo_1_wr_en <= 0;
        fifo_2_wr_en <= 0;
      end
    end
  end

  //读出FIFO的逻辑 
  //FIFO的输出逻辑主要由这个状态机来实现
  always_ff @(posedge clk or negedge rst_n) begin : FIFO_1_read_out
    if (rst_n == 0) begin
      fifo_state <= FIFO_IDLE;
      fifo_cnt   <= 0;
      fifo_1_rd_en <= 0;
      fifo_2_rd_en <= 0;
      first           <= 1;
    end else begin
      case (fifo_state)
        FIFO_IDLE: begin
          if(tree_search_start) begin
            fifo_state <= FIFO_SEARCH ;
          end
          fifo_cnt   <= 0;
          fifo_1_rd_en <= 0;
          fifo_2_rd_en <= 0;
          first           <= 1;
        end
        FIFO_SEARCH:begin
          if(searching_done) begin
            fifo_state <= FIFO_OUTPUT;
            fifo_1_rd_en <= 0;
          end else if(fifo_1_empty == 0) begin
              fifo_1_rd_en <= 1;
              fifo_state <= FIFO_STALL_1_C;
              first <=0;
          end else begin
            fifo_1_rd_en <= 0;
          end
        end
        FIFO_STALL_1_C:begin
          fifo_state <= FIFO_SEARCH_THIS_ANCHOR;
          fifo_1_rd_en <= 0;
        end
        FIFO_SEARCH_THIS_ANCHOR:begin
          if(fifo_cnt == r_fifo_1_anchor_num-1)begin
              fifo_1_rd_en <= 0;
              fifo_state <= FIFO_SEARCH;
              fifo_cnt <= 0;
          end else begin
            fifo_1_rd_en <= 0;
            fifo_cnt <= fifo_cnt +1;
          end
        end
        FIFO_OUTPUT:begin
          if(fifo_2_empty == 0) begin
            fifo_2_rd_en <= 1;
            fifo_state <= FIFO_OUTPUT_THIS_ANCHOR;
             
          end else begin
            fifo_state <= FIFO_IDLE;
          end
        end
        FIFO_OUTPUT_THIS_ANCHOR:begin
          if((fifo_cnt == r_fifo_2_anchor_num-1) & (in_anchor_cnt == FEATURE_LENGTH))begin
            if(fifo_2_empty == 0) begin
              fifo_2_rd_en <= 1;
              fifo_cnt <= 0;
              in_anchor_cnt <= 0;
            end else begin
              fifo_state <= FIFO_OUTPUT;
              in_anchor_cnt <= 0;
              fifo_cnt <= 0;
            end
          end else begin
            fifo_2_rd_en <= 0;
            if(in_anchor_cnt == FEATURE_LENGTH)begin
              fifo_cnt <= fifo_cnt+1;
              in_anchor_cnt <= 1;
            end else  begin
              in_anchor_cnt <= in_anchor_cnt+1;
            end
          end
        end
        default:begin
          fifo_state <= FIFO_IDLE;
        end
      endcase
    end
  end


  always_ff @(posedge clk or negedge rst_n) begin : read_write_to_sram
    if (rst_n == 0) begin
      mem_sram_CEN        <= 1;
      mem_sram_D          <= 0;
      mem_sram_GWEN       <= 1;
    end else begin
      if (tree_search_start) begin
        mem_sram_CEN        <= 0;
        mem_sram_D          <= 0;
        mem_sram_GWEN       <= 1;
      end else begin
        if(fifo_1_rd_en |
           fifo_2_rd_en |
           ((fifo_state == FIFO_SEARCH_THIS_ANCHOR) &(fifo_cnt != r_fifo_1_anchor_num-1))|
           ((fifo_state == FIFO_OUTPUT_THIS_ANCHOR) &((fifo_cnt != r_fifo_2_anchor_num-1)|
           (in_anchor_cnt != FEATURE_LENGTH)))) begin
          mem_sram_CEN        <= 0;
          mem_sram_D          <= 0;
          mem_sram_GWEN       <= 1;
        end else begin
          mem_sram_D          <= 0;
          mem_sram_CEN        <= 1;
          mem_sram_GWEN       <= 1;
        end
      end
    end
  end

    assign      mem_sram_A           = address_for_sram;
    assign      feature_out          = (fifo_state == FIFO_OUTPUT_THIS_ANCHOR)?mem_sram_Q:0;
    assign      out_ready            = (fifo_state == FIFO_OUTPUT_THIS_ANCHOR);
    assign      mem_read_data_valid_pre= ~mem_sram_CEN;

  //准备地址相关信息 根据当前的fifo cnt 准备好要抓取的anchor的位置。
  always_comb begin : gen_level_offset_from_fifo_data
    if (tree_state == SEARCH) begin
      r_fifo_1_anchor_num = fifo_1_rdata[3:0];
      r_fifo_2_anchor_num = 0;
      level = (first)?0:fifo_1_rdata[FIFO_DATA_WIDTH-1-:$clog2(TREE_LEVEL)]+1;
      for (int a = 0; a < 5; a += 1) begin
        if (a == {30'd0, fifo_1_rdata[FIFO_DATA_WIDTH-1-:$clog2(TREE_LEVEL)]} ) begin
          offset[a]=rdata_1_slice[fifo_cnt];
        end else begin
          offset[a] = fifo_1_rdata[FIFO_DATA_WIDTH-$clog2(TREE_LEVEL)-1-a*3-:3];
        end
      end
    end else if (tree_state == OUT) begin
      r_fifo_1_anchor_num = 0;
      r_fifo_2_anchor_num = fifo_2_rdata[3:0];;
      level = (first)?0:fifo_2_rdata[FIFO_DATA_WIDTH-1-:$clog2(TREE_LEVEL)];
      for (int a = 0; a < 5; a += 1) begin
        if (a == {29'd0, fifo_2_rdata[FIFO_DATA_WIDTH-1-:3]} ) begin
          offset[a]=rdata_2_slice[fifo_cnt];
        end else begin
          offset[a] =fifo_2_rdata[FIFO_DATA_WIDTH-$clog2(TREE_LEVEL)-1-a*3-:3];
        end
      end
    end else begin
      r_fifo_1_anchor_num = 0;
      r_fifo_2_anchor_num = 0;
      level= 0;
      for (int a = 0; a < 5; a += 1) offset[a] = 0;
    end
  end

  always_comb begin : interested_slice_of_fifo_rdata
    if(rst_n ==0) begin
      for(int i = 0 ;i<8;i+=1)begin
        rdata_1_slice[i] = 0 ;
        rdata_2_slice[i] = 0 ;
      end
    end else begin
      for(int i = 0 ;i<8;i+=1)begin
        rdata_1_slice[i] = fifo_1_rdata[FIFO_DATA_WIDTH-ENCODE_ADDR_WIDTH-1-i*3 -:3];
        rdata_2_slice[i] = fifo_2_rdata[FIFO_DATA_WIDTH-ENCODE_ADDR_WIDTH-1-i*3 -:3];
      end
    end
  end

  //保存当前搜索的anchor的相关信息。
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_posencode <= 14'd0;
      anchor_interested <= 0;
    end else begin
      // 组成格式：|level[2:0]| offset0[2:0] | offset1[2:0] | offset2[2:0] | offset3[2:0] | offset4[2:0]|
      mem_posencode <= {level, offset[0],offset[1], offset[2],offset[3]};
      w_fifo_pos_encode <= mem_posencode;
      anchor_interested <= actual_address[1:0];
    end
  end

  

  // 在tree结构中计算实际地址 // TODO：增加hash的访存逻辑，最后将计算得到的输出也赋值给address_for_sram
  always_comb begin
    if (tree_state == SEARCH) begin
      address_part_ = 0;
      for (int i = 0; i < 5; i += 1) begin
        if (i < level) begin
          if (i == 0) begin
            address_part_ += 586 * offset[i];
          end else begin
            address_part_ += offset[i] * (1'b1) << (2* ({30'd0, level} - i));
          end
        end
      end
      actual_address   = address_part_ + ADDR_VARY[level] + TREE_START_ADDR;
      address_for_sram = {2'b0, actual_address[63:2]};
      //same_addr        = (address_for_sram == last_addr_read) ? 1 : 0;// TODO：可以加一个同一地址的信号，用于标识是否有必要再次访存？
    end else if (tree_state == OUT) begin                           //TODO:生成hash寻址逻辑
      address_part_ = 0;
      actual_address = 0;
      address_for_sram = FEATURE_START_ADDR + {53'd0,hash_addr[10:0]} * 9 + {60'd0,in_anchor_cnt} - 1;// Direct mappin
    end else begin
      address_part_    = 0;
      actual_address   = 0;
      address_for_sram = 0;
    end
  end

  //哈希算法，用于计算每一个encode pos 的具体地址。
  always_comb begin
    if (!rst_n) begin
      hash_addr = 64'd0;
    end else if (tree_state == OUT) begin                           // OUT 状态
      case (level)
        0: hash_addr = {61'd0,offset[0]}+1;
        1: hash_addr = {61'd0,offset[0]}+1 + ({61'd0,offset[1]} + 64'd1) * 8;
        2: hash_addr = (({61'd0,offset[0]} + 64'd1) * PRIMES[0]
                     ^ ({61'd0,offset[1]} + 64'd1) * PRIMES[1]
                     ^ ({61'd0,offset[2]} + 64'd1) * PRIMES[2] )+ 64'd72;
        3: hash_addr = (({61'd0,offset[0]} + 64'd1) * PRIMES[0]
                     ^ ({61'd0,offset[1]} + 64'd1) * PRIMES[1]
                     ^ ({61'd0,offset[2]} + 64'd1) * PRIMES[2]
                     ^ ({61'd0,offset[3]} + 64'd1) * PRIMES[3] )+ 64'd72;
//        4: hash_addr = ((offset[0] + 64'd1) * PRIMES[0]
//                     ^ (offset[1] + 64'd1) * PRIMES[1]
//                     ^ (offset[2] + 64'd1) * PRIMES[2]
//                     ^ (offset[3] + 64'd1) * PRIMES[3]
//                     ^ (offset[4] + 64'd1) * PRIMES[4] )+ 64'd72;
        default: hash_addr = 64'd0;
      endcase
    end else begin
      hash_addr = 64'd0;
    end
  end


  //生成总的状态转移控制信号
  always_ff @( posedge clk or negedge rst_n ) begin : gen_extra_data
    if(rst_n == 0) begin
      searching_done <= 0;
      outing_done    <= 0;
    end else begin
      if((tree_state == SEARCH) &
        fifo_1_empty &
        ((write_fifo_data_valid+mem_read_data_valid_pre+mem_read_data_valid+fifo_1_wr_en )==0))begin
        //当搜索fifo空，并且流水线中不存在任何有效数据时，搜索结束
        searching_done <= 1;
      end else if((tree_state == OUT) & fifo_2_empty& (fifo_state ==FIFO_IDLE) )begin
        outing_done <= 1;
      end else begin
        outing_done <= 0;
        searching_done <= 0;
      end
    end
  end

  //流水线中的数据有效信号依次进行传递
  always_ff @(posedge clk or negedge rst_n) begin : valid_signal_in_pipline
    if (rst_n == 0) begin
      write_fifo_data_valid <= 0;
      mem_read_data_valid   <= 0;
    end else begin
      write_fifo_data_valid <= mem_read_data_valid;
      mem_read_data_valid   <=  mem_read_data_valid_pre;
    end
  end

  //FIFO——1 用于存储搜索的信息
  fifo_sync #(
    .DATA_WIDTH                  (FIFO_DATA_WIDTH           ),
    .DEPTH                       (FIFO_DEPTH_1              ) 
  ) u_fifo_sync_1 (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .wr_en                       (fifo_1_wr_en              ),
    .rd_en                       (fifo_1_rd_en              ),
    .wdata                       (fifo_1_wdata              ),
    .rdata                       (fifo_1_rdata              ),
    .empty                       (fifo_1_empty              ),
    .full                        (fifo_1_full               ) 
  );

  //FIFO——2 用于存储anchor相关的信息。
  fifo_sync #(
    .DATA_WIDTH                  (FIFO_DATA_WIDTH           ),
    .DEPTH                       (FIFO_DEPTH_2              ) 
  ) u_fifo_sync_2 (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .wr_en                       (fifo_2_wr_en              ),
    .rd_en                       (fifo_2_rd_en              ),
    .wdata                       (fifo_2_wdata              ),
    .rdata                       (fifo_2_rdata              ),
    .empty                       (fifo_2_empty              ),
    .full                        (fifo_2_full               ) 
  );

endmodule
