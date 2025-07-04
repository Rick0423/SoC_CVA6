`timescale 1ns / 1ps
module Octree_wrapper(
    input                               clk_i                      ,
    input                               rstn_i                     ,
    input                               mem_req_i                  ,
    input                               mem_write_en_i             ,
    input              [64/8-1: 0]      mem_byte_en_i              ,
    input                [64-1: 0]      mem_addr_i                 ,
    input                [64-1: 0]      mem_wdata_i                ,
    output               [64-1: 0]      mem_rdata_o                 
);

    wire      [3*4+$clog2(4)-1: 0]      csr_pos_encode              ;
    wire                 [   1: 0]      csr_ctrl                    ;
    wire                 [   3: 0]      csr_tree_num                ;
    wire                 [   1: 0]      csr_op_done                 ;
    wire              [4:0][15: 0]      csr_lod_param               ;
    wire                                csr_local_sram_en           ;
    wire                                csr_in_out_sram_en          ;

    wire                                axi_in_out_SRAM_req_i       ;
    wire                                axi_in_out_SRAM_we_i        ;
    wire                 [  63: 0]      axi_in_out_SRAM_addr_i      ;
    wire                 [  63: 0]      axi_in_out_SRAM_wdata_i     ;
    wire                 [  63: 0]      axi_in_out_SRAM_rdata_o     ;

    wire                                axi_local_SRAM_req_i        ;
    wire                                axi_local_SRAM_we_i         ;
    wire                 [  63: 0]      axi_local_SRAM_addr_i       ;
    wire                 [  63: 0]      axi_local_SRAM_wdata_i      ;
    wire                 [  63: 0]      axi_local_SRAM_rdata_o      ;

Octree#(
    .FEATURE_LENTH               (10                        ),
    .TREE_LEVEL                  (4                         ),
    .ENCODE_ADDR_WIDTH           (3*4+$clog2(4)             ),
    .TREE_START_ADDR             (0                         ),
    .LOD_START_ADDR              (500                       ),
    .FEATURE_START_ADDR          (400                       ),
    .INPUT_FEATURE_START_ADDR    (0                         ),
    .OUTPUT_FEATURE_START_ADDR   (10                        ) 
)
 u_Octree(
    .clk                         (clk_i                       ),
    .rst_n                       (rstn_i                     ),
    .csr_lod_param               (csr_lod_param             ),
    .csr_pos_encode              (csr_pos_encode            ),// level | offset 0 | offset  1 | offset  2 | offset  3
    .csr_ctrl                    (csr_ctrl                  ),// 0 IDLE; 1 search tree;2 add anchor; 3 delete anchor
    .csr_tree_num                (csr_tree_num              ),// （take 8 for now）
    .csr_op_done                 (csr_op_done               ),// 00 IDLE;01 search_done;02 add_done;03 del_done
    .csr_local_sram_en           (csr_local_sram_en         ),
    .csr_in_out_sram_en          (csr_in_out_sram_en        ),
//in_out_sram for testing
    .axi_in_out_SRAM_req_i       (axi_in_out_SRAM_req_i     ),
    .axi_in_out_SRAM_we_i        (axi_in_out_SRAM_we_i      ),
    .axi_in_out_SRAM_addr_i      (axi_in_out_SRAM_addr_i    ),
    .axi_in_out_SRAM_wdata_i     (axi_in_out_SRAM_wdata_i   ),
    .axi_in_out_SRAM_rdata_o     (axi_in_out_SRAM_rdata_o   ),
//main_memory
    .axi_local_SRAM_req_i        (axi_local_SRAM_req_i      ),
    .axi_local_SRAM_we_i         (axi_local_SRAM_we_i       ),
    .axi_local_SRAM_addr_i       (axi_local_SRAM_addr_i     ),
    .axi_local_SRAM_wdata_i      (axi_local_SRAM_wdata_i    ),
    .axi_local_SRAM_rdata_o      (axi_local_SRAM_rdata_o    ) 
);

endmodule