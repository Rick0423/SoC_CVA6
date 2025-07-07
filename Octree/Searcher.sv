`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-04
// Update Date:     2025-07-07
// Design Name:     Octree
// Project Name:    VLSI-26 3DGS
// Description:     Searcher for rendering 
//////////////////////////////////////////////////////////////////////////////////
module Searcher #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH               = 10    ,
    parameter       TREE_START_ADDR             = 0     ,
    parameter       LOD_START_ADDR              = 1000   ,
    parameter       FEATURE_START_ADDR          = 80  ,
    parameter       ENCODE_ADDR_WIDTH           = 3 * TREE_LEVEL + $clog2(TREE_LEVEL),
    parameter       FIFO_DATA_WIDTH             = ENCODE_ADDR_WIDTH + 3+1+3*8, //+1原因在于0-8需要4bit数据来表示
    parameter       FIFO_DEPTH_1                = ENCODE_ADDR_WIDTH + 10,
    parameter       FIFO_DEPTH_2                = ENCODE_ADDR_WIDTH + 10
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //control 
    input                               search_start               ,
    output reg                          search_done                ,
  //local sram
    output                              mem_sram_CEN               ,
    output               [   9: 0]      mem_sram_A                 ,
    output               [  63: 0]      mem_sram_D                 ,
    output                              mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //ouput sram
    output                              out_sram_CEN            ,
    output               [   9: 0]      out_sram_A              ,
    output               [  63: 0]      out_sram_D              ,
    output                              out_sram_GWEN           ,
    input                [  63: 0]      out_sram_Q              ,
  //csr_lod_param
    input             [2:0][15: 0]      cam_pos                    ,
    input                [  15: 0]      dist_max                   ,
    input                [  15: 0]      s                          ,
  //totle octree num, default 4
    input                [   3: 0]      tree_num                    
);
  //sram_muxing 
    localparam      [   1: 0] SRAM_LOD                    = 0     , 
                              SRAM_SEARCH                 = 1     ;
  //FSM states 
    localparam      [   1: 0] IDLE                        = 0     , 
                              LOD                         = 1     ,
                              TREE_SEARCH                 = 2     ,
                              DONE                        = 3     ;

    reg                  [   3: 0]      tree_cnt                    ;// 0-8 
  //local_sram_interface
    wire                                lod_sram_CEN                ;
    wire                 [  63: 0]      lod_sram_A                  ;
    wire                 [  63: 0]      lod_sram_D                  ;
    wire                                lod_sram_GWEN               ;
    wire                 [  63: 0]      lod_sram_Q                  ;
    wire                                search_sram_CEN             ;
    wire                 [   9: 0]      search_sram_A               ;
    wire                 [  63: 0]      search_sram_D               ;
    wire                                search_sram_GWEN            ;
    wire                 [  63: 0]      search_sram_Q               ;
  //for clearing the cnter for output sram
    wire                                search_done_for_clear       ;
  //lod_comput_interface
    wire         [TREE_LEVEL-1: 0]      lod_active                  ;
    wire                                lod_ready                   ;
    reg                                 cal_lod                     ;
  //tree_serarch_control
    wire                                tree_search_done            ;
    reg                                 tree_search_start           ;

    reg                  [   1: 0]      mem_select                  ;
    reg                  [   1: 0]      searcher_state              ;
    reg          [TREE_LEVEL-1: 0]      lod_active_reg              ;

  //Muxing Lod and Tree_search sram 
    assign      mem_sram_CEN         = (mem_select == SRAM_LOD)    ? lod_sram_CEN    :
                                       (mem_select == SRAM_SEARCH) ? search_sram_CEN :  1'b1;
    assign      mem_sram_A           = (mem_select == SRAM_LOD)    ? lod_sram_A[9:0] :
                                       (mem_select == SRAM_SEARCH) ? search_sram_A   :  '0;
    assign      mem_sram_D           = (mem_select == SRAM_LOD)    ? lod_sram_D      :
                                       (mem_select == SRAM_SEARCH) ? search_sram_D   :  '0;
    assign      mem_sram_GWEN        = (mem_select == SRAM_LOD)    ? lod_sram_GWEN   :
                                       (mem_select == SRAM_SEARCH) ? search_sram_GWEN:  1'b1;
    assign      search_sram_Q        = (mem_select == SRAM_SEARCH) ? mem_sram_Q      :  '0;
    assign      lod_sram_Q           = (mem_select == SRAM_LOD)    ? mem_sram_Q      :  '0;

    assign      search_done_for_clear= search_done;

  //FSM for lod and Tree_search schedule
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
    .FEATURE_LENGTH              (FEATURE_LENGTH            ),
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
    .tree_cnt                    (tree_cnt                  ),
    .lod_active                  (lod_active_reg            ),
    .search_done_for_clear       (search_done_for_clear     ),
    //local_sram
    .mem_sram_CEN                (search_sram_CEN           ),
    .mem_sram_A                  (search_sram_A             ),
    .mem_sram_D                  (search_sram_D             ),
    .mem_sram_GWEN               (search_sram_GWEN          ),
    .mem_sram_Q                  (search_sram_Q             ),
    //output_sram
    .out_sram_CEN                (out_sram_CEN              ),
    .out_sram_A                  (out_sram_A                ),
    .out_sram_D                  (out_sram_D                ),
    .out_sram_GWEN               (out_sram_GWEN             ),
    .out_sram_Q                  (out_sram_Q                ) 
  );
  
  
endmodule

module tree_search #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH              = 10    ,
    parameter       TREE_START_ADDR             = 0     ,
    parameter       FEATURE_START_ADDR          = 80    ,
    parameter       ENCODE_ADDR_WIDTH           = 3 * TREE_LEVEL + $clog2(TREE_LEVEL),
    parameter       FIFO_DATA_WIDTH             = ENCODE_ADDR_WIDTH + 3+1+3*8, //+1原因在与0-8需要4bit数据来表示
    parameter       FIFO_DEPTH_1                = ENCODE_ADDR_WIDTH + 10,
    parameter       FIFO_DEPTH_2                = ENCODE_ADDR_WIDTH + 10
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //control
    input                               tree_search_start          ,
    output reg                          tree_search_done           ,
    input                [   3: 0]      tree_cnt                   ,
    input        [TREE_LEVEL-1: 0]      lod_active                 ,
    input                               search_done_for_clear      ,
  //local sram
    output reg                          mem_sram_CEN               ,
    output               [   9: 0]      mem_sram_A                 ,
    output reg           [  63: 0]      mem_sram_D                 ,
    output reg                          mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //ouput sram
    output reg                          out_sram_CEN               ,
    output               [   9: 0]      out_sram_A                 ,
    output reg           [  63: 0]      out_sram_D                 ,
    output reg                          out_sram_GWEN              ,
    input                [  63: 0]      out_sram_Q                  
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

    localparam      [4:0][11: 0] ADDR_VARY                   = {12'd74, 12'd10, 12'd2, 12'd1, 12'd0};
    localparam      [3:0][ 7: 0] PRIMES                      = {8'd19, 8'd23, 8'd29, 8'd31};  
  //cnters and states
    reg                  [   3: 0]      fifo_cnt                    ,
                                        hash_cnt                    ,
                                        self_fifo_cnt               ;
    reg                  [   1: 0]      tree_state                  ;
    reg                  [   2: 0]      child_fifo_state            ,
                                        self_fifo_state             ;
  //control signal
    reg                                 outing_done                 ;
    reg                                 searching_done              ;
  //ready to search data to write into fifo 
    reg                  [   7: 0]      self_data                   ;
    reg                [7:0][2: 0]      self_ones_pos               ;
    reg                  [   3: 0]      self_ones_count             ;
    reg                  [   7: 0]      child_data                  ;
    reg                [7:0][2: 0]      child_ones_pos              ;
    reg                  [   3: 0]      child_ones_count            ;
  //valid signals in pipeline 
    reg                                 self_child_valid            ;
    reg                                 child_rdata_valid           ;
    reg                                 self_rdata_valid            ;
  //fifo interface
    reg                                 child_fifo_wr_en            ;
    reg                                 child_fifo_rd_en            ;
    reg                                 child_fifo_empty            ;
    reg                                 child_fifo_full             ;
    reg     [FIFO_DATA_WIDTH-1: 0]      child_fifo_wdata            ;
    reg     [FIFO_DATA_WIDTH-1: 0]      child_fifo_rdata            ;
    reg                                 self_fifo_wr_en             ;
    reg                                 self_fifo_rd_en             ;
    reg                                 self_fifo_empty             ;
    reg                                 self_fifo_full              ;
    reg     [FIFO_DATA_WIDTH-1: 0]      self_fifo_wdata             ;
    reg     [FIFO_DATA_WIDTH-1: 0]      self_fifo_rdata             ;
  //extract signals    data read from fifo 
    logic [ENCODE_ADDR_WIDTH-1: 0]      child_fifo_pos_encode       ;
    logic                [   3: 0]      child_fifo_anchor_num       ;
    logic              [7:0][2: 0]      child_rdata_slice           ;
    logic [ENCODE_ADDR_WIDTH-1: 0]      self_fifo_pos_encode        ;
    logic                [   3: 0]      self_fifo_anchor_num        ;
    logic              [7:0][2: 0]      self_rdata_slice            ;
  //Tree searching  addr generation  
    logic [ENCODE_ADDR_WIDTH-1: 0]      tree_pos_to_calculate       ;
    logic[$clog2(TREE_LEVEL)-1: 0]      tree_level                  ;
    logic                [ 3-1: 0]      tree_offset[TREE_LEVEL-1:0] ;
    logic                [  11: 0]      tree_address_part_          ;
    logic                [  11: 0]      tree_addr_within_tree_16bit ;
    logic                [   9: 0]      tree_actual_address         ;
  //for tree pos encode gen
    logic                [  11: 0]      tmp_offset                  ;
    logic[$clog2(TREE_LEVEL)-1: 0]      tmp_level                   ;
  //Feature fatching addr generation 
    logic [ENCODE_ADDR_WIDTH-1: 0]      hash_pos_to_calculate       ;
    logic[$clog2(TREE_LEVEL)-1: 0]      hash_level                  ;
    logic                [ 3-1: 0]      hash_offset[TREE_LEVEL-1:0] ;
    logic                [   9: 0]      hash_encoded_addr           ;
    logic                [   9: 0]      hash_actual_address         ;
    logic                [  63: 0]      fast_hash_2,fast_hash_3     ;
  //for hash pos encode gen
    logic                [  11: 0]      tmp1_offset                 ;
    logic[$clog2(TREE_LEVEL)-1: 0]      tmp1_level                  ;
  //sram muxing interface 
    reg                  [   9: 0]      child_mem_A                 ;
    reg                                 child_mem_valid             ;
    reg                  [   9: 0]      self_mem_A                  ;
    reg                                 self_mem_valid              ;

    assign      mem_sram_D           = 0;// No writing 
    assign      mem_sram_GWEN        = 1;// No writing 
    assign      mem_sram_A           = (tree_state == SEARCH)?~child_mem_A:
                                       (tree_state == OUT)?~self_mem_A:0;
    assign      mem_sram_CEN         = (tree_state == SEARCH)?~child_mem_valid:
                                       (tree_state == OUT)?~self_mem_valid:1;
  
    ///////////////////////////////////////
    // Top state machine controler
    ///////////////////////////////////////

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

    ///////////////////////////////////////
    // fifo write data generation  
    // mem_sram_Q -> {child_w_fifo_pos_encode, child_ones_pos, child_ones_count},
    //               {self_w_fifo_pos_encode, child_ones_pos, child_ones_count}
    ///////////////////////////////////////

  //hold child_data and self_data from mem_Q read
  always_ff @( posedge clk or negedge rst_n ) begin : get_intersted_data
    if(rst_n == 0) begin
      self_data <= 0;
      child_data <= 0;
    end else if((child_mem_valid)&&(tree_state == SEARCH)) begin
      for (int i = 0; i < 8; i++) begin : bit_separation
            child_data[i] <= mem_sram_Q[tree_addr_within_tree_16bit[1:0]*8*2+2*i]; // 提取偶数位
            self_data[i]  <= mem_sram_Q[tree_addr_within_tree_16bit[1:0]*8*2+2*i + 1];// 提取奇数位
            self_child_valid <= 1;
        end
    end else begin
        self_child_valid <= 0;
    end
  end

  //generate self_ones_pos,self_ones_count,
  int i, j;
  always_comb begin 
  //default values
    self_ones_count = 0;
    for (int i = 0; i < 8; i = i + 1) self_ones_pos[i] = 0;
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (self_data[i]) begin
        self_ones_pos[j] = i[2:0];                                  
        j                = j + 1;
      end
    end
    self_ones_count = j[3:0];
  end

  //generate child_ones_count,child_pos_count
  int u, o;
  always_comb begin 
  //default values
    child_ones_count = 0;
    for (int u = 0; u < 8; u = u + 1) child_ones_pos[u] = 0;
    o = 0;
    for (u = 0; u < 8; u = u + 1) begin
      if (child_data[u]) begin
        child_ones_pos[o] = u[2:0];                                 
        o                 = o + 1;
      end
    end
    child_ones_count = o[3:0];
  end

  //writing fifo 
  always_ff @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
      child_fifo_wr_en <= 0;
      self_fifo_wr_en <= 0;
      child_fifo_wdata <= 0;
      self_fifo_wdata <= 0;
    end else begin
      if (self_child_valid && (tree_state == SEARCH)) begin         // only write fifo in searching phase
        if((child_ones_count != 0 ) && lod_active[tree_level+1]) begin
          child_fifo_wr_en <= 1;
          child_fifo_wdata <= {tree_level+2'd1,tree_offset[0],tree_offset[1],tree_offset[2],tree_offset[3],child_ones_pos,child_ones_count};
        end else begin
          child_fifo_wr_en <= 0;
          child_fifo_wdata <= '0;
        end
      if((self_ones_count != 0 ) && lod_active[tree_level]) begin         // lod_active should always high here, just in case
          self_fifo_wr_en <= 1;
          self_fifo_wdata <= {tree_level,tree_offset[0],tree_offset[1],tree_offset[2],tree_offset[3], self_ones_pos, self_ones_count};
        end else begin
          self_fifo_wr_en <= 0;
        end
      end else begin
        self_fifo_wr_en <= 0;
        child_fifo_wr_en <= 0;
      end
    end
  end

    ///////////////////////////////////////
    // fifo read  signal
    // extract signals data read from fifo 
    ///////////////////////////////////////
 
  always_ff@(posedge clk or negedge rst_n) begin                    //child fifo 
    if(rst_n==0)begin
      child_fifo_anchor_num <= '0   ;
      child_fifo_pos_encode <= '0   ;
      for(int i=0;i<8;i+=1)
          child_rdata_slice[i]<= '0 ;
    end else if(child_rdata_valid) begin
        child_fifo_anchor_num <= child_fifo_rdata[3:0];
        child_fifo_pos_encode <= child_fifo_rdata[FIFO_DATA_WIDTH-1 -: ENCODE_ADDR_WIDTH];
        for(int i=0;i<8;i+=1)
          child_rdata_slice[i]<= child_fifo_rdata[FIFO_DATA_WIDTH-ENCODE_ADDR_WIDTH-1-i*3 -:3];
    end
  end

  always_ff@(posedge clk or negedge rst_n) begin                    //self fifo
    if(rst_n==0)begin
      self_fifo_anchor_num <= '0   ;
      self_fifo_pos_encode <= '0   ;
      for(int i=0;i<8;i+=1)
          self_rdata_slice[i]<= '0 ;
    end else if(self_rdata_valid) begin
        self_fifo_anchor_num <= self_fifo_rdata[3:0];
        self_fifo_pos_encode <= self_fifo_rdata[FIFO_DATA_WIDTH-1 -: ENCODE_ADDR_WIDTH];
        for(int i=0;i<8;i+=1)
          self_rdata_slice[i]<= self_fifo_rdata[FIFO_DATA_WIDTH-ENCODE_ADDR_WIDTH-1-i*3 -:3];
    end
  end

    ///////////////////////////////////////
    // Child fifo read controler 
    // responsible for searching tree
    ///////////////////////////////////////

  always_ff @(posedge clk or negedge rst_n) begin : FIFO_1_read_out
    if (rst_n == 0) begin
      child_fifo_state <= FIFO_IDLE;      
      child_fifo_rd_en <= 0;
      child_rdata_valid <= 0;
      fifo_cnt   <= 0;
    end else begin
      case (child_fifo_state)
        FIFO_IDLE: begin
          if(tree_search_start) begin
            child_fifo_state <= FIFO_SEARCH ;
            child_mem_A      <= 0;
            child_mem_valid  <= 1;
          end
          fifo_cnt   <= 0;
          child_fifo_rd_en <= 0;
          child_rdata_valid <= 0;
        end
        FIFO_SEARCH:begin
          if(searching_done) begin
            child_fifo_state <= FIFO_OUTPUT;
            child_fifo_rd_en <= 0;
            child_rdata_valid <= 0;
          end else if(child_fifo_empty == 0) begin
              child_fifo_rd_en <= 1;
              child_rdata_valid <= 1;
              child_fifo_state <= FIFO_STALL_1_C;
          end else begin
            child_fifo_rd_en <= 0;
            child_rdata_valid <= 0;
          end
        end
        FIFO_STALL_1_C:begin
          child_fifo_state <= FIFO_SEARCH_THIS_ANCHOR;
          child_fifo_rd_en <= 0;
        end
        FIFO_SEARCH_THIS_ANCHOR:begin
          if(fifo_cnt == child_fifo_anchor_num-1)begin
              child_fifo_state <= FIFO_SEARCH;
              fifo_cnt <= 0;
          end else begin
            fifo_cnt <= fifo_cnt +1;
            child_mem_valid <= 1;
          end
        end
        default:begin
          child_fifo_state <= FIFO_IDLE;      
          child_fifo_rd_en <= 0;
          child_rdata_valid <= 0;
          fifo_cnt   <= 0;
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tree_pos_to_calculate <= '0;
    end else begin
      {tmp_level, tmp_offset} = child_fifo_pos_encode;
      tmp_offset[11-tmp1_level*3 -: 3] = child_rdata_slice[fifo_cnt];
      tree_pos_to_calculate <= {tmp_level, tmp_offset};
    end
  end

    ///////////////////////////////////////
    // self fifo read controler 
    // responsible for Outputing tree
    ///////////////////////////////////////

  always_ff @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
      self_fifo_state <= FIFO_IDLE;      
      self_fifo_rd_en <= 0;
      self_rdata_valid <= 0;
      self_fifo_cnt   <= 0;
    end else begin
      case (self_fifo_state)
        FIFO_IDLE: begin
          if(tree_search_start) begin
            self_fifo_state <= FIFO_SEARCH ;
            self_mem_A      <= 0;
            self_mem_valid  <= 1;
          end
          fifo_cnt   <= 0;
          self_fifo_rd_en <= 0;
          self_rdata_valid <= 0;
        end
        FIFO_OUTPUT:begin
          if(self_fifo_empty == 0) begin
            self_fifo_rd_en <= 1;
            self_fifo_state <= FIFO_OUTPUT_THIS_ANCHOR;
            self_rdata_valid <= 1;
            self_fifo_cnt    <= 0;
          end else begin
            self_fifo_state <= FIFO_IDLE;
          end
        end
        FIFO_OUTPUT_THIS_ANCHOR:begin
          if((self_fifo_cnt == self_fifo_anchor_num-1) & (hash_cnt == FEATURE_LENGTH))begin
            if(self_fifo_empty == 0) begin
              self_fifo_rd_en <= 1;
              self_rdata_valid <= 1;
              self_fifo_cnt <= 0;
              hash_cnt <= 0;
            end else begin
              self_fifo_state <= FIFO_OUTPUT;
              hash_cnt <= 0;
              self_fifo_cnt <= 0;
            end
          end else begin
            self_fifo_rd_en <= 0;
            if(hash_cnt == FEATURE_LENGTH)begin
              self_fifo_cnt <= self_fifo_cnt+1;
              hash_cnt <= 1;
            end else  begin
              hash_cnt <= hash_cnt+1;
            end
          end
        end
        default:begin
          self_fifo_state <= FIFO_IDLE;
        end
      endcase
    end
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hash_pos_to_calculate <= '0;
    end else begin
      {tmp1_level, tmp1_offset} = self_fifo_pos_encode;
      tmp_offset[11-tmp1_level*3 -: 3] = self_rdata_slice[self_fifo_cnt];
      hash_pos_to_calculate <= {tmp1_level, tmp1_offset};
    end
  end



    ///////////////////////////////////////
    // Tree search finish signal generation 
    ///////////////////////////////////////

  always_ff @( posedge clk or negedge rst_n ) begin : gen_extra_data
    if(rst_n == 0) begin
      searching_done <= 0;
      outing_done    <= 0;
    end else begin
      if((tree_state == SEARCH) &
         (child_fifo_empty) &
         (child_rdata_valid+child_mem_valid+child_fifo_wr_en==0))begin
        searching_done <= 1;
      end else if((tree_state == OUT) & self_fifo_empty & (self_fifo_state ==FIFO_IDLE) )begin
        outing_done <= 1;
      end else begin
        outing_done <= 0;
        searching_done <= 0;
      end
    end
  end


    ///////////////////////////////////////
    // Tree Search Addr Generation 
    // tree_pos_to_calculate -> tree_actual_address
    ///////////////////////////////////////

  always_comb  begin
    tree_level = tree_pos_to_calculate[ENCODE_ADDR_WIDTH-1 -: $clog2(TREE_LEVEL)];
    for (int a = 0; a < TREE_LEVEL; a += 1) begin
       tree_offset[a] = tree_pos_to_calculate[ENCODE_ADDR_WIDTH-1-$clog2(TREE_LEVEL)-a*3 -:3];
    end
  end

  always_comb begin
    case (tree_level)
        0: tree_addr_within_tree_16bit  = 0+ ADDR_VARY[tree_level] ;
        1: tree_addr_within_tree_16bit  = 0+ ADDR_VARY[tree_level] ;
        2: tree_addr_within_tree_16bit  = {9'd0,tree_offset[1]}+ ADDR_VARY[tree_level] ;
        3: tree_addr_within_tree_16bit  = tree_offset[1] * 8 + {9'd0,tree_offset[2]}+ ADDR_VARY[tree_level] ;
        default: begin
           tree_addr_within_tree_16bit = 0;
        end
    endcase
    tree_actual_address    = tree_addr_within_tree_16bit[11:2] + 19 * tree_offset[0] + TREE_START_ADDR;
    //same_addr    = (address_for_sram == last_addr_read);
  end

    ///////////////////////////////////////
    // Hashing Addr Generation 
    // hash_pos_to_calculate -> hash_actual_address
    ///////////////////////////////////////

  always_comb  begin
    hash_level = hash_pos_to_calculate[ENCODE_ADDR_WIDTH-1 -: $clog2(TREE_LEVEL)];
    for (int a = 0; a < TREE_LEVEL; a += 1) begin
       hash_offset[a] = hash_pos_to_calculate[ENCODE_ADDR_WIDTH-1-$clog2(TREE_LEVEL)-a*3 -:3];
    end
  end
  //split here if path is too long
  assign fast_hash_2 = (({61'd0,hash_offset[0]} + 1) * PRIMES[0]) 
                      ^ (({61'd0,hash_offset[1]} + 1) * PRIMES[1] )
                      ^ (({61'd0,hash_offset[2]} + 1) * PRIMES[2] );

  assign fast_hash_3 = (({61'd0,hash_offset[0]} + 1) * PRIMES[0] )
                   ^ (({61'd0,hash_offset[1]} + 1) * PRIMES[1] )
                   ^ (({61'd0,hash_offset[2]} + 1) * PRIMES[2] )
                   ^ (({61'd0,hash_offset[3]} + 1) * PRIMES[3] );

  always_comb begin
    case (hash_level)
      0: hash_encoded_addr = {7'd0,hash_offset[0]} ;
      1: hash_encoded_addr = (({7'd0,hash_offset[0]}+1) * 8) +{7'd0,hash_offset[0]};
      2: hash_encoded_addr = ({4'd0,fast_hash_2[5:0]}>54)? {4'd0,fast_hash_2[5:0]}:{4'd0,fast_hash_2[5:0]}+ 10'd36;
      3: hash_encoded_addr = ({4'd0,fast_hash_3[5:0]}>54)? {4'd0,fast_hash_3[5:0]}:{4'd0,fast_hash_3[5:0]}+ 10'd36;
      default: hash_encoded_addr = 10'd0;
    endcase
    hash_actual_address = hash_encoded_addr * 10 + FEATURE_START_ADDR + {6'd0,hash_cnt} - 10'd1;
  end


  //FIFO——1 用于存储搜索的信息
  fifo_sync #(
    .DATA_WIDTH                  (FIFO_DATA_WIDTH           ),
    .DEPTH                       (FIFO_DEPTH_1              ) 
  ) u_fifo_sync_1 (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .wr_en                       (child_fifo_wr_en              ),
    .rd_en                       (child_fifo_rd_en              ),
    .wdata                       (child_fifo_wdata              ),
    .rdata                       (child_fifo_rdata              ),
    .empty                       (child_fifo_empty              ),
    .full                        (child_fifo_full               ) 
  );

  //FIFO——2 用于存储anchor相关的信息。
  fifo_sync #(
    .DATA_WIDTH                  (FIFO_DATA_WIDTH           ),
    .DEPTH                       (FIFO_DEPTH_2              ) 
  ) u_fifo_sync_2 (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .wr_en                       (self_fifo_wr_en              ),
    .rd_en                       (self_fifo_rd_en              ),
    .wdata                       (self_fifo_wdata              ),
    .rdata                       (self_fifo_rdata              ),
    .empty                       (self_fifo_empty              ),
    .full                        (self_fifo_full               ) 
  );

endmodule
