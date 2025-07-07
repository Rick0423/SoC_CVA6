`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Create Date:     2025-07-04
// Update Date:     2025-07-07
// Design Name:     Octree
// Project Name:    VLSI-26 3DGS
// Description:     Updator of the Octree, adding / deleting anchors
//////////////////////////////////////////////////////////////////////////////////
module Updater #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH              = 10    , // anchor_feature + pos + level 36*16+4*16 =64*10
    parameter       ENCODE_ADDR_WIDTH           = 3*TREE_LEVEL+$clog2(TREE_LEVEL), //14b { level(2b)|offset 0(3b)| 1 (3b)| 2 (3b)| 3 (3b)}
    parameter       TREE_START_ADDR             = 0     ,
    parameter       FEATURE_START_ADDR          = 80   
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //control
    input                               add_anchor                 ,
    input                               del_anchor                 ,
    output                              add_done                   ,
    output                              del_done                   ,
  //csr
    input [ENCODE_ADDR_WIDTH-1: 0]      pos_encode                 ,
  //local sram
    output                              mem_sram_CEN               ,
    output               [   9: 0]      mem_sram_A                 ,
    output               [  63: 0]      mem_sram_D                 ,
    output                              mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //input sram
    output                              in_sram_CEN                ,
    output               [   9: 0]      in_sram_A                  ,
    output               [  63: 0]      in_sram_D                  ,
    output                              in_sram_GWEN               ,
    input                [  63: 0]      in_sram_Q                   
);
  typedef enum logic [2:0] {
    IDLE,
    ADDING,
    DELETING
  } state_e;
    state_e                             state_updater               ;

    logic                               add_sram_CEN                ;
    logic                [   9: 0]      add_sram_A                  ;
    logic                [  63: 0]      add_sram_D                  ;
    logic                               add_sram_GWEN               ;
    logic                [  63: 0]      add_sram_Q                  ;

    logic                               del_sram_CEN                ;
    logic                [   9: 0]      del_sram_A                  ;
    logic                [  63: 0]      del_sram_D                  ;
    logic                               del_sram_GWEN               ;
    logic                [  63: 0]      del_sram_Q                  ;
  

  //updater状态机
  always_ff @(posedge clk or negedge rst_n) begin : updater_top_state_machine
    if (rst_n == 0) begin
      state_updater <= IDLE;
    end else begin
      case (state_updater)
        IDLE: begin
          if (add_anchor) begin
            state_updater <= ADDING;
          end else if (del_anchor) begin
            state_updater <= DELETING;
          end
        end
        ADDING: begin
          if (add_done) begin
            state_updater <= IDLE;
          end
        end
        DELETING: begin
          if (del_done) begin
            state_updater <= IDLE;
          end
        end
        default: begin
          state_updater <= IDLE;
        end
      endcase
    end
  end

  //Sram Muxing 
    assign      mem_sram_A           = (state_updater == ADDING)   ? add_sram_A  :
                                       (state_updater == DELETING) ? del_sram_A  :'0;
    assign      mem_sram_D           = (state_updater == ADDING)   ? add_sram_D  :  
                                       (state_updater == DELETING) ? del_sram_D  :'0;
    assign      mem_sram_GWEN        = (state_updater == IDLE)     ? 1'b1        :
                                       (state_updater == ADDING)   ? add_sram_GWEN:
                                       (state_updater == DELETING) ? del_sram_GWEN:1'b1;
    assign      mem_sram_CEN         = (state_updater == IDLE)     ? 1'b1        :
                                       (state_updater == ADDING)   ? add_sram_CEN:
                                       (state_updater == DELETING) ? del_sram_CEN:1'b1;
    assign      add_sram_Q           = (state_updater == ADDING)   ? mem_sram_Q  : '0;
    assign      del_sram_Q           = (state_updater == DELETING) ? mem_sram_Q  : '0;

  //initialization 
  Add_anchor #(
    .TREE_LEVEL                  (TREE_LEVEL                ),
    .FEATURE_LENGTH              (FEATURE_LENGTH             ),
    .ENCODE_ADDR_WIDTH           (ENCODE_ADDR_WIDTH         ),
    .TREE_START_ADDR             (TREE_START_ADDR           ),
    .FEATURE_START_ADDR          (FEATURE_START_ADDR        ) 
  ) Add (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .add_anchor                  (add_anchor                ),
    .add_done                    (add_done                  ),
    .pos_encode                  (pos_encode                ),
  //local sram  
    .mem_sram_CEN                (add_sram_CEN              ),
    .mem_sram_A                  (add_sram_A                ),
    .mem_sram_D                  (add_sram_D                ),
    .mem_sram_GWEN               (add_sram_GWEN             ),
    .mem_sram_Q                  (add_sram_Q                ),
  //input sram
    .in_sram_CEN                 (in_sram_CEN               ),
    .in_sram_A                   (in_sram_A                 ),
    .in_sram_D                   (in_sram_D                 ),
    .in_sram_GWEN                (in_sram_GWEN              ),
    .in_sram_Q                   (in_sram_Q                 ) 
  );

  Delete_anchor #(
    .TREE_LEVEL                  (TREE_LEVEL                ),
    .ENCODE_ADDR_WIDTH           (ENCODE_ADDR_WIDTH         ),
    .TREE_START_ADDR             (TREE_START_ADDR           ) 
  ) del (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .del_anchor                  (del_anchor                ),
    .del_done                    (del_done                  ),
    .pos_encode                  (pos_encode                ),
  //local sram   
    .mem_sram_CEN                (del_sram_CEN              ),
    .mem_sram_A                  (del_sram_A                ),
    .mem_sram_D                  (del_sram_D                ),
    .mem_sram_GWEN               (del_sram_GWEN             ),
    .mem_sram_Q                  (del_sram_Q                )
  );
endmodule

module Delete_anchor #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       ENCODE_ADDR_WIDTH           = 3*TREE_LEVEL+$clog2(TREE_LEVEL) , //14b { level(2b)|offset 0(3b)| 1 (3b)| 2 (3b)| 3 (3b)}
    parameter       TREE_START_ADDR             = 0     
) (
    input                               clk                        ,
    input                               rst_n                      ,
    input                               del_anchor                 ,
    output reg                          del_done                   ,
    input [ENCODE_ADDR_WIDTH-1: 0]      pos_encode                 ,

    output reg                          mem_sram_CEN               ,
    output reg           [   9: 0]      mem_sram_A                 ,
    output reg           [  63: 0]      mem_sram_D                 ,
    output reg                          mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                  
);

  typedef enum logic [1:0] {
    IDLE,
    UPDATE_SELF,
    UPDATE_PARENT,
    DONE
  } state_e;

  state_e delete_state;

    localparam      [4:0][11: 0]ADDR_VARY                   = {12'd74, 12'd10, 12'd2, 12'd1, 12'd0};

    reg   [ENCODE_ADDR_WIDTH-1: 0]      reg_pos                     ;
    reg                  [   3: 0]      cnt                         ;
    reg                  [  15: 0]      anchor_data                 ;

    logic [ENCODE_ADDR_WIDTH-1: 0]      tree_pos_to_calculate       ;
    logic[$clog2(TREE_LEVEL)-1: 0]      tree_level                  ;
    logic                [ 3-1: 0]      tree_offset[TREE_LEVEL-1:0] ;
    logic                [  11: 0]      tree_address_part_          ;
    logic                [  11: 0]      tree_addr_within_tree_16bit ;
    logic                [   9: 0]      tree_actual_address         ;

    reg                                 parent_all_invalid          ;
    reg                                 self_all_invalid            ;

    assign      anchor_data          = mem_sram_Q[({2'b0, tree_addr_within_tree_16bit[1:0]}-4'd1)*2*8-1-:2*8];
    assign      parent_all_invalid   = ((anchor_data & (~(16'd1 << (tree_offset[tree_level] * 2)))) == 16'd0);
    assign      self_all_invalid     = ((anchor_data & (~(16'd1 << (tree_offset[tree_level] * 2 + 1)))) == 16'd0);

  ///////////////////////////////////////
  // FSM Deleting anchor
  ///////////////////////////////////////

  always_ff @(posedge clk or negedge rst_n) begin : main_logic_update_sram
    if (rst_n == 0) begin
      delete_state <= IDLE;
      cnt          <= 0;
      del_done     <=0;
      reg_pos <= 'd0;
    end else begin
      case (delete_state)
        IDLE: begin
          if (del_anchor) begin
            delete_state      <= UPDATE_SELF;
            cnt               <= 0;
            tree_pos_to_calculate <= pos_encode;
            reg_pos           <= pos_encode;
          end
          mem_sram_CEN  <= 1;
          mem_sram_D    <= 0;
          mem_sram_GWEN <= 1;
          del_done <=0;
          cnt <= 0;
        end
        UPDATE_SELF: begin
          //无论如何更新自己写回。
          //如果孩子位有效，则直接返回
          //如果孩子位无效，则检查同级的人是否有效，如果有效则直接返回
          //如果均无效则需要更新父亲节点。进入update——parent节点
          if (cnt == 0) begin
            mem_sram_CEN  <= 0;
            mem_sram_A    <= tree_actual_address;
            mem_sram_GWEN <= 1;
            cnt <= cnt+1;
          end else if (cnt == 1) begin
            mem_sram_CEN <= 0;
            mem_sram_A    <= tree_actual_address;
            mem_sram_D    <= mem_sram_Q & (~(64'd1<<(tree_addr_within_tree_16bit[1:0]*2*8+tree_offset[tree_level]*2+1)));
            mem_sram_GWEN <= 0;
            if (self_all_invalid) begin
              if (tree_level == 0) begin
                delete_state <= DONE;
              end else begin
                delete_state      <= UPDATE_PARENT;
                tree_pos_to_calculate <= {tree_level - 2'd1, reg_pos[3*TREE_LEVEL-1:0]};
                cnt               <= 0;
              end
            end else begin
              delete_state <= DONE;
            end
          end
        end
        UPDATE_PARENT: begin
          if (cnt == 0) begin
            //考虑一下第零级的事情
            //读父亲级的信息，
            mem_sram_CEN  <= 0;
            mem_sram_A    <= tree_actual_address;
            mem_sram_GWEN <= 1;
            cnt <= cnt +1;
          end else if (cnt == 1) begin
            //无论如何都需要将父亲的孩子位写为0，写回
            //如果父亲级所有人都无效，在此进行UPDATE_PARENT,cnt清零，否则直接返回。
            mem_sram_CEN  <= 0;
            mem_sram_A    <= tree_actual_address;
            mem_sram_D    <= mem_sram_Q & (~(64'd1<<(tree_addr_within_tree_16bit[1:0]*2*8+tree_offset[tree_level]*2)));
            mem_sram_GWEN <= 0;
            if (parent_all_invalid) begin
              if (tree_level == 0) begin
                delete_state <= DONE;
              end else begin
                delete_state      <= UPDATE_PARENT;
                tree_pos_to_calculate <= {tree_level - 2'd1, reg_pos[3*4-1:0]};
                cnt               <= 0;
              end
            end else begin
              delete_state <= DONE;
            end
          end
        end
        DONE: begin
          del_done <= 1;
          delete_state <= IDLE;
          cnt <= 0;
          mem_sram_GWEN <= 1;
          mem_sram_CEN <= 1;
        end
        default: begin
        end
      endcase
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
  end
endmodule

module Add_anchor #(
    parameter       TREE_LEVEL                  = 4     ,
    parameter       FEATURE_LENGTH              = 10    ,  // anchor_feature + pos + level 36*16+4*16 =64*10
    parameter       ENCODE_ADDR_WIDTH           = 3*TREE_LEVEL+$clog2(TREE_LEVEL), //14b { level(2b)|offset 0(3b)| 1 (3b)| 2 (3b)| 3 (3b)}
    parameter       TREE_START_ADDR             = 0     ,
    parameter       FEATURE_START_ADDR          = 80    ,
    parameter       IN_START_ADDR               = 0
) (
    input                               clk                        ,
    input                               rst_n                      ,
  //control
    input                               add_anchor                 ,
    output reg                          add_done                   ,
  //csr
    input [ENCODE_ADDR_WIDTH-1: 0]      pos_encode                 ,
  //local srma
    output reg                          mem_sram_CEN               ,
    output reg           [   9: 0]      mem_sram_A                 ,
    output reg           [  63: 0]      mem_sram_D                 ,
    output reg                          mem_sram_GWEN              ,
    input                [  63: 0]      mem_sram_Q                 ,
  //input sram
    output reg                          in_sram_CEN                ,
    output reg           [   9: 0]      in_sram_A                  ,
    output reg           [  63: 0]      in_sram_D                  ,
    output reg                          in_sram_GWEN               ,
    input                [  63: 0]      in_sram_Q                  
);
    localparam      [   2: 0] IDLE                        = 0     , 
                              UPDATE_SELF                 = 2     , 
                              UPDATE_PARENT               = 3     , 
                              WRITE_FEATURE               = 4     ;

    localparam      [4:0][11: 0] ADDR_VARY                   = {12'd74, 12'd10, 12'd2, 12'd1, 12'd0};
    localparam      [3:0][ 7: 0] PRIMES                      = {8'd19, 8'd23, 8'd29, 8'd31};  // 质数数组，增强哈希随机性

    reg                  [   2: 0]      add_state                   ;
    reg                  [   3: 0]      input_cnt,                
                                        cnt,
                                        hash_cnt;
  //hold input pos_encode
    reg   [ENCODE_ADDR_WIDTH-1: 0]      reg_pos                     ;
  //Tree searching   
    logic [ENCODE_ADDR_WIDTH-1: 0]      tree_pos_to_calculate       ;
    logic[$clog2(TREE_LEVEL)-1: 0]      tree_level                  ;
    logic                [ 3-1: 0]      tree_offset[TREE_LEVEL-1:0]  ;
    logic                [  11: 0]      tree_address_part_          ;
    logic                [  11: 0]      tree_addr_within_tree_16bit  ;
    logic                [   9: 0]      tree_actual_address         ;
  //Feature fatching
    logic [ENCODE_ADDR_WIDTH-1: 0]      hash_pos_to_calculate       ;
    logic[$clog2(TREE_LEVEL)-1: 0]      hash_level                  ;
    logic                [ 3-1: 0]      hash_offset[TREE_LEVEL-1:0]  ;
    logic                [   9: 0]      hash_encoded_addr           ;
    logic                [   9: 0]      hash_actual_address         ;

    logic                [  15: 0]      anchor_data                 ;
    logic                               self_all_invalid            ;
    logic                               parent_all_invalid          ;

    logic                [  63: 0]      fast_hash_2                 ;
    logic                [  63: 0]      fast_hash_3                 ;

    // extract 16bit part interested in  
    assign      anchor_data          = mem_sram_Q[({2'b0, tree_addr_within_tree_16bit[1:0]}-4'd1)*2*8-1-:2*8];
    assign      parent_all_invalid   = ((anchor_data & (~(16'd1 << (tree_offset[tree_level] * 2)))) == 16'd0);
    assign      self_all_invalid     = ((anchor_data & (~(16'd1 << (tree_offset[tree_level] * 2 + 1)))) == 16'd0);

    ///////////////////////////////////////
    // Main Upadte logic 
    //      FSM
    ///////////////////////////////////////
    
  always_ff @(posedge clk or negedge rst_n) begin : write_to_sram
    if (rst_n == 0) begin
      cnt       <= 0;
      add_state <= IDLE;
      add_done <= 0;
      mem_sram_GWEN <= 1;
      mem_sram_CEN  <=1; 
      mem_sram_D   <= 0;
      tree_pos_to_calculate <= '0;
    end else begin
      case (add_state)
        IDLE: begin
          cnt <= 0;
          mem_sram_GWEN <=1;
          mem_sram_CEN  <=1;
          if (add_anchor) begin
            //准备进行访存，准备好地址数据
            add_state         <= UPDATE_SELF;
            tree_pos_to_calculate <= pos_encode;
          end
        end
        UPDATE_SELF: begin
          if (cnt == 0) begin
            //读新增的anchor同级的所有元素信息。
            mem_sram_CEN  <= 0;
            mem_sram_A    <=  tree_actual_address;
            mem_sram_GWEN <= 1;
            cnt           <= cnt + 1;
          end else if (cnt == 1) begin
            //拿到新增的anchor同级的所有元素信息，检查是否全部为空，如果是更新新增的一位的自己哪一位，进入UPDATE_PARENT
            //否则更新自己的那一位，然后直接进入下一阶段。
            cnt <= 0;
            mem_sram_CEN <= 0;
            mem_sram_A    <=  tree_actual_address;
            mem_sram_GWEN <= 0;
            mem_sram_D <= mem_sram_Q | (64'd1<<(tree_addr_within_tree_16bit[1:0]*2*8+tree_offset[tree_level]*2+1));
            if (self_all_invalid) begin
              if (tree_level == 0) begin
                add_state <= WRITE_FEATURE;
              end else begin
                add_state         <= UPDATE_PARENT;
                tree_pos_to_calculate <= {tree_level - 2'd1, reg_pos[3*TREE_LEVEL-1:0]};
              end
            end else begin
              add_state <= WRITE_FEATURE;
            end
          end
        end
        UPDATE_PARENT: begin
          if (cnt == 0) begin
            //读父亲节点的anchor同级的所有元素信息
            mem_sram_CEN  <= 0;
            mem_sram_A    <=  tree_actual_address;
            mem_sram_GWEN <= 1;
            cnt           <= cnt + 1;
          end else if (cnt == 1) begin
            //检查父亲节点的anchor是否全空，如果是，则写入对应的孩子位，然后继续向上递归。cnt清零
            //如果不是，则写入对应的孩子位，然后返回。cnt清零
            cnt <= 0;
            mem_sram_CEN <= 0;
            mem_sram_A    <=  tree_actual_address;
            mem_sram_GWEN <= 0;
            mem_sram_D <= mem_sram_Q | (64'd1<<(tree_addr_within_tree_16bit[1:0]*2*8+tree_offset[tree_level]*2));
            if (parent_all_invalid) begin 
              cnt <= 0;
              if(tree_level == 0)begin
                add_state <= WRITE_FEATURE;
                in_sram_CEN <= 0;
                hash_cnt <= 0;
                hash_pos_to_calculate <= reg_pos;
              end else begin
                add_state <= UPDATE_PARENT;
                tree_pos_to_calculate <= {tree_level - 2'd1, reg_pos[3*TREE_LEVEL-1:0]};
              end
            end else begin
              add_state <= WRITE_FEATURE;
              in_sram_CEN <= 0;
              in_sram_A <= IN_START_ADDR + {6'd0,hash_cnt};
              hash_cnt <= 0;
              hash_pos_to_calculate <= reg_pos;
            end
          end
        end
        WRITE_FEATURE: begin
          if (hash_cnt == FEATURE_LENGTH) begin
            //返回add_done，返回IDLE状态。
            add_done <= 1;
            add_state <= IDLE;
            hash_cnt<=0;
            mem_sram_CEN <= 1;
            mem_sram_GWEN <= 1;
          end else begin
            mem_sram_CEN <= 0;
            mem_sram_A   <= hash_actual_address ;
            mem_sram_D   <= in_sram_Q;
            mem_sram_GWEN <= 0;
            hash_cnt <= hash_cnt + 1;
            //正常的写主存往hash_addr+cnt的位置写
          end
        end
        default: begin
          add_state <= IDLE;
          cnt       <= 0;
          hash_cnt  <= 0;
          add_done  <= 0;
        end
      endcase
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

endmodule