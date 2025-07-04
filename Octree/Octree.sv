`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Designer:        Renati Tuerhong 
// Acknowledgement: Chatgpt
// Date:            2025-07-04
// Design Name:     Octree_wrapper
// Project Name:    VLSI-26 3DGS
// Description:     Octree top module 
//////////////////////////////////////////////////////////////////////////////////
module Octree #(
    parameter       FEATURE_LENGTH              = 10    ,//for a single anchor_feature : 36*16=64*9 + pos 3dim level 1dim 
    parameter       TREE_LEVEL                  = 4     ,
    parameter       ENCODE_ADDR_WIDTH           = 3*TREE_LEVEL+$clog2(TREE_LEVEL),//3*4+2  = 14 bit | level | offset 0 | offset  1 | offset  2 | offset  3 |
    parameter       TREE_START_ADDR             = 0     ,
    parameter       LOD_START_ADDR              = 500   ,
    parameter       FEATURE_START_ADDR          = 400   ,
    parameter       INPUT_FEATURE_START_ADDR    = 0     ,
    parameter       OUTPUT_FEATURE_START_ADDR   = 10    
) (
    input                               clk                        ,
    input                               rst_n                      ,

    input [ENCODE_ADDR_WIDTH-1: 0]      csr_pos_encode             ,// level | offset 0 | offset  1 | offset  2 | offset  3 
    input                [   1: 0]      csr_ctrl                   ,// 0 IDLE; 1 search tree;2 add anchor; 3 delete anchor
    input                [   3: 0]      csr_tree_num               ,//（take 8 for now）
    input             [4:0][15: 0]      csr_lod_param              ,// 0-2 cam_pos;3 dist_max; 4 s 
    output               [   1: 0]      csr_op_done                ,// 00 IDLE;01 search_done;02 add_done;03 del_done
    input                               csr_local_sram_en          ,
    input                               csr_in_out_sram_en         ,
    //in_out_sram for testing
    input                               axi_in_out_SRAM_req_i         ,
    input                               axi_in_out_SRAM_we_i          ,
    input                [  9: 0]      axi_in_out_SRAM_addr_i        ,
    input                [  63: 0]      axi_in_out_SRAM_wdata_i       ,
    output               [  63: 0]      axi_in_out_SRAM_rdata_o       ,
    //main_memory
    input                               axi_local_SRAM_req_i          ,
    input                               axi_local_SRAM_we_i           ,
    input                [  9: 0]      axi_local_SRAM_addr_i         ,
    input                [  63: 0]      axi_local_SRAM_wdata_i        ,
    output               [  63: 0]      axi_local_SRAM_rdata_o         
  );

  // Muxing_Sram
    localparam      [   1: 0] SRAM_NAN                    = 0     ,
                              SRAM_SEARCHER               = 1     ,
                              SRAM_UPDATER                = 2     ;

    localparam      [   1: 0] IN_OUT_IDLE                 = 0     ,
                              IN_OUT_IN                   = 1     ,
                              IN_OUT_OUT                  = 2     ;

  // Control_signal
    wire                                search_start                ;
    wire                                add_anchor                  ;
    wire                                del_anchor                  ;
    wire                                add_done                    ;
    wire                                del_done                    ;
    wire                                search_done                 ;
    wire                 [   1: 0]      mem_select                  ;
  // Main_Memmory_for_Searcher
    wire                                searcher_sram_CEN           ;
    wire                 [  63: 0]      searcher_sram_A             ;
    wire                 [  63: 0]      searcher_sram_D             ;
    wire                 [  63: 0]      searcher_sram_Q             ;
    wire                                searcher_sram_GWEN          ;
  // Main_Memmory_for_Updater
    wire                                updater_sram_CEN            ;
    wire                 [  63: 0]      updater_sram_A              ;
    wire                 [  63: 0]      updater_sram_D              ;
    wire                 [  63: 0]      updater_sram_Q              ;
    wire                                updater_sram_GWEN           ;
  //Level_of_details_cal_param
    wire              [2:0][15: 0]      cam_pos                     ;
    wire                 [  15: 0]      dist_max                    ;
    wire                 [  15: 0]      s                           ;
  //In_out_sram_data
    wire                 [  63: 0]      feature_out                 ;
    wire                 [  63: 0]      feature_in                  ;
    wire                                out_ready                   ;

    reg                  [   1: 0]      in_out_state                ;
    reg                  [   3: 0]      in_out_cnt                  ;
    reg                                 reading_input_features      ;

    reg                                 in_out_sram_CEN             ;
    reg                  [  63: 0]      in_out_sram_A               ;
    reg                  [  63: 0]      in_out_sram_D               ;
    reg                                 in_out_sram_GWEN            ;
    reg                  [  63: 0]      in_out_sram_Q               ;

    reg                                 mem_sram_CEN                ;
    reg                  [  63: 0]      mem_sram_A                  ;
    reg                  [  63: 0]      mem_sram_D                  ;
    reg                                 mem_sram_GWEN               ;
    reg                  [  63: 0]      mem_sram_Q                  ;

    assign      cam_pos              = csr_lod_param[2:0];
    assign      dist_max             = csr_lod_param[3];
    assign      s                    = csr_lod_param[4];

  Control  control_inst (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .ctrl                        (csr_ctrl                  ),
    .search_start                (search_start              ),
    .search_done                 (search_done               ),
    .add_anchor                  (add_anchor                ),
    .del_anchor                  (del_anchor                ),
    .add_done                    (add_done                  ),
    .del_done                    (del_done                  ),
    .mem_select                  (mem_select                ) 
  );

  Searcher #(
    .TREE_LEVEL                  (TREE_LEVEL                ),
    .FEATURE_LENGTH              (FEATURE_LENGTH             ),
    .TREE_START_ADDR             (TREE_START_ADDR           ),
    .LOD_START_ADDR              (LOD_START_ADDR            ),
    .FEATURE_START_ADDR          (FEATURE_START_ADDR        ),
    .ENCODE_ADDR_WIDTH           (ENCODE_ADDR_WIDTH         ) 
  ) searcher_inst (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .search_start                (search_start              ),
    .search_done                 (search_done               ),
    .cam_pos                     (cam_pos                   ),
    .feature_out                 (feature_out               ),
    .out_ready                   (out_ready                 ),
    .dist_max                    (dist_max                  ),
    .s                           (s                         ),
    .tree_num                    (csr_tree_num              ),

    .mem_sram_CEN                (searcher_sram_CEN         ),
    .mem_sram_A                  (searcher_sram_A           ),
    .mem_sram_D                  (searcher_sram_D           ),
    .mem_sram_GWEN               (searcher_sram_GWEN        ),
    .mem_sram_Q                  (searcher_sram_Q           ) 
  );

  Updater #(
    .TREE_LEVEL                  (TREE_LEVEL                ),
    .TREE_START_ADDR             (TREE_START_ADDR           ),
    .FEATURE_START_ADDR          (FEATURE_START_ADDR        ),
    .ENCODE_ADDR_WIDTH           (ENCODE_ADDR_WIDTH         ),
    .FEATURE_LENGTH              (FEATURE_LENGTH             ) 
  ) updater_inst (
    .clk                         (clk                       ),
    .rst_n                       (rst_n                     ),
    .add_anchor                  (add_anchor                ),
    .del_anchor                  (del_anchor                ),
    .add_done                    (add_done                  ),
    .del_done                    (del_done                  ),
    .pos_encode                  (csr_pos_encode            ),
    .feature_in                  (feature_in                ),

    .mem_sram_CEN                (updater_sram_CEN          ),
    .mem_sram_A                  (updater_sram_A            ),
    .mem_sram_D                  (updater_sram_D            ),
    .mem_sram_GWEN               (updater_sram_GWEN         ),
    .mem_sram_Q                  (updater_sram_Q            ) 
  );
    //Muxing upadter and searcher 
    assign      mem_sram_CEN         = (mem_select == SRAM_SEARCHER) ? searcher_sram_CEN :
                                       (mem_select == SRAM_UPDATER)  ? updater_sram_CEN  :1'b1;
    assign      mem_sram_A           = (mem_select == SRAM_SEARCHER) ? searcher_sram_A :
                                       (mem_select == SRAM_UPDATER)  ? updater_sram_A  : '0;
    assign      mem_sram_D           = (mem_select == SRAM_SEARCHER) ? searcher_sram_D :
                                       (mem_select == SRAM_UPDATER)  ? updater_sram_D  :  '0;
    assign      mem_sram_GWEN        = (mem_select == SRAM_SEARCHER) ? searcher_sram_GWEN : 
                                       (mem_select == SRAM_UPDATER)  ? updater_sram_GWEN  : 1'b1;
    assign      searcher_sram_Q      = (mem_select == SRAM_SEARCHER) ? mem_sram_Q : '0;
    assign      updater_sram_Q       = (mem_select == SRAM_UPDATER)  ? mem_sram_Q : '0;
    //00 IDLE;01 search_done;02 add_done;03 del_done
    assign      csr_op_done          = (search_done == 1 ) ? 2'b01 : 
                                       (add_done == 1 ) ? 2'b10 :
                                       (del_done == 1 ) ? 2'b11 : 2'b00;

    //Input_Output_data scatter_gather
    always_ff @(posedge clk or negedge rst_n) begin : data_scatter_gather
      if(rst_n == 0 ) begin
          in_out_sram_CEN   <= 1;
          in_out_sram_A     <= 0;
          in_out_sram_D     <= 0;
          in_out_sram_GWEN  <= 1;
          in_out_cnt        <= 0;
      end else begin
          case(in_out_state)
            IN_OUT_IDLE:begin
              if(csr_ctrl == 2'b10) begin
                in_out_sram_CEN <= 0;
                in_out_sram_A   <= 0;
                in_out_cnt      <= 0;
                in_out_state    <= IN_OUT_IN;
              end else if(out_ready) begin
                in_out_state    <= IN_OUT_OUT;
                in_out_sram_CEN <= 0;
                in_out_sram_A   <= 0;
                in_out_cnt      <= 0;
              end else begin
                in_out_sram_CEN   <= 1;
                in_out_sram_A     <= 0;
                in_out_sram_D     <= 0;
                in_out_sram_GWEN  <= 1;
                in_out_cnt        <= 0;
              end
            end
            IN_OUT_IN:begin
                if(in_out_cnt == FEATURE_LENGTH)begin
                    in_out_state <= IN_OUT_IDLE;
                    in_out_sram_CEN <= 1;
                    in_out_cnt   <= 0;
                end else begin
                    in_out_sram_CEN   <= 0;
                    in_out_sram_A     <=  INPUT_FEATURE_START_ADDR + {60'd0,in_out_cnt};
                    in_out_cnt  <= in_out_cnt +1;
                end
            end
            IN_OUT_OUT:begin
                if(in_out_cnt == FEATURE_LENGTH)begin
                    in_out_state <= IN_OUT_IDLE;
                    in_out_sram_CEN <= 1;
                    in_out_sram_GWEN<= 1;
                    in_out_cnt   <= 0;
                end else begin
                    in_out_sram_GWEN  <= 0;
                    in_out_sram_CEN   <= 0;
                    in_out_sram_A     <=  OUTPUT_FEATURE_START_ADDR + {60'd0,in_out_cnt};
                    in_out_cnt  <= in_out_cnt +1;
                end
            end
            default:begin
              in_out_sram_CEN   <= 1;
              in_out_sram_A     <= 0;
              in_out_sram_D     <= 0;
              in_out_sram_GWEN  <= 1;
              in_out_cnt        <= 0;
            end
          endcase
      end
    end

    assign      feature_in           = (in_out_state== IN_OUT_IN) ? in_out_sram_Q:0;

    // SRAM initialization
    wire                                local_SRAM_req_i            ;
    wire                                local_SRAM_we_i             ;
    wire                 [10-1: 0]      local_SRAM_addr_i           ;
    wire                 [  63: 0]      local_SRAM_wdata_i          ;
    wire                 [  63: 0]      local_SRAM_rdata_o          ;

    wire                                in_out_SRAM_req_i           ;
    wire                                in_out_SRAM_we_i            ;
    wire                 [10-1: 0]      in_out_SRAM_addr_i          ;
    wire                 [  63: 0]      in_out_SRAM_wdata_i         ;
    wire                 [  63: 0]      in_out_SRAM_rdata_o         ;

  local_sram_8KB #(
    .ADDR_WIDTH                  (10                        ),
    .DATA_WIDTH                  (64                        ),
    .MEM_DEPTH                   (1                         ),
    .INIT_FILE                   ("local_sram_init.hex"     ) 
  )
  u_local_sram_8KB(
    .clk                         (clk                       ),// Clock
    .rst_n                       (rst_n                     ),// Active-low reset
    .sram_req_i                  (local_SRAM_req_i          ),// Chip enable (active high)
    .sram_we_i                   (local_SRAM_we_i           ),// Write enable (active high)
    .sram_addr_i                 (local_SRAM_addr_i         ),// Address bus
    .sram_wdata_i                (local_SRAM_wdata_i        ),// Write data bus
    .sram_rdata_o                (local_SRAM_rdata_o        ) // Read data bus
  );

  in_out_sram_8KB #(
    .ADDR_WIDTH                  (10                        ),
    .DATA_WIDTH                  (64                        ),
    .MEM_DEPTH                   (1                         ),
    .INIT_FILE                   ("in_out_sram_init.hex"    ) 
  )
   u_in_out_sram_8KB(
    .clk                         (clk                       ),// Clock
    .rst_n                       (rst_n                     ),// Active-low reset
    .sram_req_i                  (in_out_SRAM_req_i         ),// Chip enable (active high)
    .sram_we_i                   (in_out_SRAM_we_i          ),// Write enable (active high)
    .sram_addr_i                 (in_out_SRAM_addr_i        ),// Address bus
    .sram_wdata_i                (in_out_SRAM_wdata_i       ),// Write data bus
    .sram_rdata_o                (in_out_SRAM_rdata_o       ) // Read data bus
  );

//Muxing external sram with internel sram 

    assign      in_out_SRAM_req_i    = (csr_local_sram_en == 1) ? axi_in_out_SRAM_req_i : (~in_out_sram_CEN);
    assign      in_out_SRAM_we_i     = (csr_local_sram_en == 1) ? axi_in_out_SRAM_we_i :(~in_out_sram_GWEN);
    assign      in_out_SRAM_addr_i   = (csr_local_sram_en == 1) ? axi_in_out_SRAM_addr_i :in_out_sram_A[9:0];
    assign      in_out_SRAM_wdata_i  = (csr_local_sram_en == 1) ? axi_in_out_SRAM_wdata_i : in_out_sram_D;
    assign      in_out_sram_Q        = (csr_local_sram_en == 1) ? 64'd0 : in_out_SRAM_rdata_o;
    assign      axi_in_out_SRAM_rdata_o= (csr_local_sram_en == 1) ? in_out_SRAM_rdata_o : 64'd0;

    assign      local_SRAM_req_i     = (csr_local_sram_en == 1) ? axi_local_SRAM_req_i  : (~mem_sram_CEN);
    assign      local_SRAM_we_i      = (csr_local_sram_en == 1) ? axi_local_SRAM_we_i   :(~mem_sram_GWEN);
    assign      local_SRAM_addr_i    = (csr_local_sram_en == 1) ? axi_local_SRAM_addr_i :mem_sram_A[9:0];
    assign      local_SRAM_wdata_i   = (csr_local_sram_en == 1) ? axi_local_SRAM_wdata_i:mem_sram_D;
    assign      mem_sram_Q           = (csr_local_sram_en == 1) ? 64'd0 : local_SRAM_rdata_o;
    assign      axi_local_SRAM_rdata_o= (csr_local_sram_en == 1) ? local_SRAM_rdata_o : 64'd0;

endmodule
