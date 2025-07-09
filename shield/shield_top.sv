`timescale 1ns / 1ps
module shield_top #(
    parameter   DATA_WIDTH                      =16                             ,
    parameter   ANCHOR_ADDR_WIDTH               =7                              ,
    parameter   ANCHOR_DATA_WIDTH               =64                             ,                
    parameter   LEVEL_ADDR_WIDTH                =4                              ,                
    parameter   LEVEL_DATA_WIDTH                =48                             ,                
    parameter   BLOCK_ADDR_WIDTH                =6                              ,                
    parameter   BLOCK_DATA_WIDTH                =64                             ,                
    parameter   SAVE_ADDR_WIDTH                 =7                              ,                
    parameter   SAVE_DATA_WIDTH                 =64                                             
)(
    input   logic                               clk                             ,
    input   logic                               rst_n                           ,

    input   logic                               csr_start_anchor_shield         ,
    input   logic                               csr_start_oct_shield            ,
    input   logic                               csr_start_get0                  ,

    input   logic [DATA_WIDTH-1:0]              csr_fx                          ,
    input   logic [DATA_WIDTH-1:0]              csr_fy                          ,
    input   logic [2:0]                         csr_block_x_idx                 ,
    input   logic [2:0]                         csr_block_y_idx                 ,
    input   logic [DATA_WIDTH-1:0]              csr_zlength                     ,                      
    input   logic [3:0][3:0][DATA_WIDTH-1:0]    csr_viewmetrics                 , 
    input   logic [7:0]                         csr_delay                       , 
    input   logic [DATA_WIDTH-1:0]              csr_distance_thresold           ,
    input   logic [DATA_WIDTH-1:0]              csr_num_thresold                ,      
    
    input   logic [ANCHOR_ADDR_WIDTH-1:0]       csr_anchor_shield_addr_end      ,       
    input   logic [ANCHOR_ADDR_WIDTH-1:0]       csr_anchor_shield_addr_start    ,  

    input   logic [LEVEL_ADDR_WIDTH-1:0]        csr_oct_shield_addr_end         ,       
    input   logic [LEVEL_ADDR_WIDTH-1:0]        csr_oct_shield_addr_start       ,  

    input   logic [ANCHOR_ADDR_WIDTH-1:0]       csr_get0_addr_end               ,       
    input   logic [ANCHOR_ADDR_WIDTH-1:0]       csr_get0_addr_start             ,     

    output  logic [31:0]                        csr_total_effective_anchor      ,
    output  logic                               csr_done_anchor_shield          ,
    output  logic                               csr_done_oct_shield             ,
    output  logic                               csr_done_get0                   ,

    input   logic                               csr_level0_reg_en               ,
    input   logic                               csr_block_sram_en               ,
    input   logic                               csr_output_sram_en              ,
    input   logic                               csr_input_sram_en               ,
    

    input   logic                               axi_level0_reg_cen_n_i          ,                                 
    input   logic                               axi_level0_reg_wen_i            ,             
    input   logic [LEVEL_ADDR_WIDTH-1:0]        axi_level0_reg_addr_i           ,           
    input   logic [LEVEL_DATA_WIDTH-1:0]        axi_level0_reg_data_in_i        ,          
    output  logic [LEVEL_DATA_WIDTH-1:0]        axi_level0_reg_data_out_o       ,
 
    input   logic                               axi_block_sram_cen_n_i          ,                                 
    input   logic                               axi_block_sram_wen_i            ,             
    input   logic [BLOCK_ADDR_WIDTH-1:0]        axi_block_sram_addr_i           ,           
    input   logic [BLOCK_DATA_WIDTH-1:0]        axi_block_sram_data_in_i        ,          
    output  logic [BLOCK_DATA_WIDTH-1:0]        axi_block_sram_data_out_o       ,

    input   logic                               axi_output_sram_cen_n_i         ,                                 
    input   logic                               axi_output_sram_wen_i           ,             
    input   logic [SAVE_ADDR_WIDTH-1:0]         axi_output_sram_addr_i          ,           
    input   logic [SAVE_DATA_WIDTH-1:0]         axi_output_sram_data_in_i       ,          
    output  logic [SAVE_DATA_WIDTH-1:0]         axi_output_sram_data_out_o      ,

    input   logic                               axi_input_sram_cen_n_i          ,                                 
    input   logic                               axi_input_sram_wen_i            ,             
    input   logic [SAVE_ADDR_WIDTH-1:0]         axi_input_sram_addr_i           ,           
    input   logic [SAVE_DATA_WIDTH-1:0]         axi_input_sram_data_in_i        ,          
    output  logic [SAVE_DATA_WIDTH-1:0]         axi_input_sram_data_out_o      
);
    logic   [1:0]                   choose;

    logic                           input_cen_n,input_cen_n_anchor,input_cen_n_get0,input_cen_n_oct,local_input_cen_n;
    logic                           input_wen,input_wen_anchor,input_wen_get0,input_wen_oct,local_input_wen;
    logic   [ANCHOR_ADDR_WIDTH-1:0] input_addr,input_addr_anchor,input_addr_get0,input_addr_oct,local_input_addr;
    logic   [ANCHOR_DATA_WIDTH-1:0] input_data_in;
    logic   [ANCHOR_DATA_WIDTH-1:0] input_data_out;

    logic                           level0_cen_n,level0_cen_n_anchor,level0_cen_n_get0,level0_cen_n_oct,local_level0_cen_n;
    logic                           level0_wen,level0_wen_anchor,level0_wen_get0,level0_wen_oct,local_level0_wen;
    logic   [LEVEL_ADDR_WIDTH-1:0]  level0_addr,level0_addr_anchor,level0_addr_get0,level0_addr_oct,local_level0_addr;
    logic   [LEVEL_DATA_WIDTH-1:0]  level0_data_in,level0_data_in_get0,level0_data_in_oct,level0_data_in_anchor,local_level0_data_in;
    logic   [LEVEL_DATA_WIDTH-1:0]  level0_data_out;

    logic                           output_cen_n,output_cen_n_anchor,output_cen_n_get0,output_cen_n_oct,local_output_cen_n;
    logic                           output_wen,output_wen_anchor,output_wen_get0,output_wen_oct,local_output_wen;
    logic   [SAVE_ADDR_WIDTH-1:0]   output_addr,output_addr_anchor,output_addr_get0,output_addr_oct,local_output_addr;
    logic   [SAVE_DATA_WIDTH-1:0]   output_data_in,output_data_in_get0,output_data_in_oct,output_data_in_anchor,local_output_data_in;
    logic   [SAVE_DATA_WIDTH-1:0]   output_data_out;

    logic                           block_cen_n,block_cen_n_anchor,block_cen_n_get0,block_cen_n_oct,local_block_cen_n;
    logic                           block_wen,block_wen_anchor,block_wen_get0,block_wen_oct,local_block_wen;
    logic   [BLOCK_ADDR_WIDTH-1:0]  block_addr,block_addr_anchor,block_addr_get0,block_addr_oct,local_block_addr;
    logic   [BLOCK_DATA_WIDTH-1:0]  block_data_in,block_data_in_get0,block_data_in_oct,block_data_in_anchor,local_block_data_in;
    logic   [BLOCK_DATA_WIDTH-1:0]  block_data_out;

    control control_inst( 
        .clk                                    (clk                                ),
        .rst_n                                  (rst_n                              ),

        .start3                                 (csr_start_anchor_shield            ),
        .done3                                  (csr_done_anchor_shield             ),
        .start2                                 (csr_start_oct_shield               ),
        .done2                                  (csr_done_oct_shield                ),
        .start1                                 (csr_start_get0                     ),
        .done1                                  (csr_done_get0                      ),
        .choose                                 (choose                             )
    );

    get0 get0_inst (
        .clk                                    (clk                                ),
        .rst_n                                  (rst_n                              ),

        .start                                  (csr_start_get0                     ),
        .distance_thresold                      (csr_distance_thresold              ),
        .num_thresold                           (csr_num_thresold                   ),
        .anchor_addr_start                      (csr_get0_addr_start                ),
        .anchor_addr_end                        (csr_get0_addr_end                  ),
        
        .anchor_cen_n                           (input_cen_n_get0                   ),
        .anchor_wen                             (input_wen_get0                     ),
        .anchor_addr_final                      (input_addr_get0                    ),
        .anchor_data_out                        (input_data_out                     ),

        .anchor_level0_cen_n                    (level0_cen_n_get0                  ),
        .anchor_level0_wen                      (level0_wen_get0                    ),
        .anchor_level0_addr_final               (level0_addr_get0                   ),
        .anchor_level0_data_in                  (level0_data_in_get0                ),
        .total_effective_anchor_out             (csr_total_effective_anchor         ),
        .done                                   (csr_done_get0                      )
    );

    anchor_shield anchor_shield_inst(
        .clk                                    (clk                                ),
        .rst_n                                  (rst_n                              ),

        .start                                  (csr_start_anchor_shield            ),
        .anchor_addr_end                        (csr_anchor_shield_addr_end         ),
        .anchor_addr_start                      (csr_anchor_shield_addr_start       ),
        .block_x_idx                            (csr_block_x_idx                    ),
        .block_y_idx                            (csr_block_y_idx                    ),
        .fx                                     (csr_fx                             ),
        .fy                                     (csr_fy                             ),
        .zlength                                (csr_zlength                        ),
        .viewmetrics                            (csr_viewmetrics                    ), 
        .delay                                  (csr_delay                          ),

        .anchor_cen_n                           (input_cen_n_anchor                 ),
        .anchor_wen                             (input_wen_anchor                   ),
        .anchor_addr_final                      (input_addr_anchor                  ),
        .anchor_data                            (input_data_out                     ),

        .block_addr                             (block_addr_anchor                  ),
        .block_cen_n                            (block_cen_n_anchor                 ),
        .block_wen                              (block_wen_anchor                   ),
        .block_data_in                          (block_data_in_anchor               ),
        .block_data_out_pre                     (block_data_out                     ),

        .anchor_cen_n_save                      (output_cen_n_anchor                ),
        .anchor_wen_save                        (output_wen_anchor                  ),
        .anchor_addr_save                       (output_addr_anchor                 ),
        .anchor_save_data_in                    (output_data_in_anchor              ),

        .done                                   (csr_done_anchor_shield             ),
        .mask                                   (                                   )
    );

    oct_shield oct_shield_inst(
        .clk                                    (clk                                ),
        .rst_n                                  (rst_n                              ),

        .start                                  (csr_start_oct_shield               ),
        .anchor_addr_end                        (csr_oct_shield_addr_end            ),
        .anchor_addr_start                      (csr_oct_shield_addr_start          ),
        .block_x_idx                            (csr_block_x_idx                    ),
        .block_y_idx                            (csr_block_y_idx                    ),
        .fx                                     (csr_fx                             ),
        .fy                                     (csr_fy                             ),
        .zlength                                (csr_zlength                        ),
        .viewmetrics                            (csr_viewmetrics                    ),

        .anchor_cen_n                           (level0_cen_n_oct                   ),
        .anchor_wen                             (level0_wen_oct                     ),
        .anchor_addr                            (level0_addr_oct                    ),       
        .anchor_data                            (level0_data_out                    ),

        .block_addr                             (block_addr_oct                     ),
        .block_cen_n                            (block_cen_n_oct                    ),
        .block_wen                              (block_wen_oct                      ),
        .block_data_in_pre                      (block_data_in_oct                  ),
        .block_data_out_pre                     (block_data_out                     ),

        .done                                   (csr_done_oct_shield                )
    );

    //64*64
    sram_block #(
        .data_width                             (BLOCK_DATA_WIDTH                   ),
        .addr_width                             (BLOCK_ADDR_WIDTH                   ),
        .depth                                  (64                                 )
    ) sram_block_inst (
        .clk                                    (clk                                ),
        .cen_n                                  (block_cen_n                        ),
        .wen                                    (block_wen                          ),
        .addr                                   (block_addr                         ),
        .data_in                                (block_data_in                      ),
        .data_out                               (block_data_out                     )
    );

    //10*48
    register_level0 #(
        .data_width                             (LEVEL_DATA_WIDTH                   ),                         
        .addr_width                             (LEVEL_ADDR_WIDTH                   ),
        .depth                                  (10                                 )
    ) register_level0_inst (
        .clk                                    (clk                                ),
        .cen_n                                  (level0_cen_n                       ),
        .wen                                    (level0_wen                         ),
        .addr                                   (level0_addr                        ),
        .data_in                                (level0_data_in                     ),
        .data_out                               (level0_data_out                    )
    );

    //128*64
    sram_output #(
        .data_width                             (SAVE_DATA_WIDTH                    ),
        .addr_width                             (SAVE_ADDR_WIDTH                    ),
        .depth                                  (128                                )
    ) sram_output_inst (
        .clk                                    (clk                                ),
        .cen_n                                  (output_cen_n                       ),
        .wen                                    (output_wen                         ),
        .addr                                   (output_addr                        ),
        .data_in                                (output_data_in                     ),
        .data_out                               (output_data_out                    )
    );

    //128*64
    sram_input #(
        .data_width                             (ANCHOR_DATA_WIDTH                  ),
        .addr_width                             (ANCHOR_ADDR_WIDTH                  ),
        .depth                                  (128                                )
    ) sram_input_inst (
        .clk                                    (clk                                ),
        .cen_n                                  (input_cen_n                        ),
        .wen                                    (input_wen                          ),
        .addr                                   (input_addr                         ),
        .data_in                                (input_data_in                      ),
        .data_out                               (input_data_out                     )
    );
    always @(*) begin
        local_input_cen_n                       = '1                                ;  
        local_input_wen                         = '0                                ;
        local_input_addr                        = '0                                ;

        local_level0_cen_n                      = '1                                ;
        local_level0_wen                        = '0                                ;
        local_level0_addr                       = '0                                ;
        local_level0_data_in                    = '0                                ;

        local_block_cen_n                       = '1                                ;
        local_block_wen                         = '0                                ;
        local_block_addr                        = '0                                ;
        local_block_data_in                     = '0                                ;

        local_output_cen_n                      = '1                                ;
        local_output_wen                        = '0                                ;
        local_output_addr                       = '0                                ;
        local_output_data_in                    = '0                                ;
        case (choose)
            2'b01: begin
                    local_input_cen_n           =input_cen_n_get0                   ; 
                    local_input_wen             =input_wen_get0                     ;
                    local_input_addr            =input_addr_get0                    ;

                    local_level0_cen_n          =level0_cen_n_get0                  ;
                    local_level0_wen            =level0_wen_get0                    ;
                    local_level0_addr           =level0_addr_get0                   ;
                    local_level0_data_in        =level0_data_in_get0                ;
            end
            2'b10: begin
                    local_level0_cen_n          =level0_cen_n_oct                   ;
                    local_level0_wen            =level0_wen_oct                     ;
                    local_level0_addr           =level0_addr_oct                    ;
                    local_level0_data_in        =level0_data_in_oct                 ;

                    local_block_cen_n           =block_cen_n_oct                    ;
                    local_block_wen             =block_wen_oct                      ;
                    local_block_addr            =block_addr_oct                     ;
                    local_block_data_in         =block_data_in_oct                  ;
            end
            2'b11: begin
                    local_input_cen_n           =input_cen_n_anchor                 ; 
                    local_input_wen             =input_wen_anchor                   ;
                    local_input_addr            =input_addr_anchor                  ;

                    local_block_cen_n           =block_cen_n_anchor                 ;
                    local_block_wen             =block_wen_anchor                   ;
                    local_block_addr            =block_addr_anchor                  ;
                    local_block_data_in         =block_data_in_anchor               ;

                    local_output_cen_n          =output_cen_n_anchor                ;
                    local_output_wen            =output_wen_anchor                  ;
                    local_output_addr           =output_addr_anchor                 ;
                    local_output_data_in        =output_data_in_anchor              ; 
            end
            default:                                                                ;
        endcase
    end

    assign  level0_cen_n                        =(csr_level0_reg_en )   ? axi_level0_reg_cen_n_i    : local_level0_cen_n    ;
    assign  level0_wen                          =(csr_level0_reg_en )   ? axi_level0_reg_wen_i      : local_level0_wen      ;
    assign  level0_addr                         =(csr_level0_reg_en )   ? axi_level0_reg_addr_i     : local_level0_addr     ;
    assign  level0_data_in                      =(csr_level0_reg_en )   ? axi_level0_reg_data_in_i  : local_level0_data_in  ;

    assign  block_cen_n                         =(csr_block_sram_en )   ? axi_block_sram_cen_n_i    : local_block_cen_n     ;
    assign  block_wen                           =(csr_block_sram_en )   ? axi_block_sram_wen_i      : local_block_wen       ;
    assign  block_addr                          =(csr_block_sram_en )   ? axi_block_sram_addr_i     : local_block_addr      ;
    assign  block_data_in                       =(csr_block_sram_en )   ? axi_block_sram_data_in_i  : local_block_data_in   ;

    assign  output_cen_n                        =(csr_output_sram_en)   ? axi_output_sram_cen_n_i   : local_output_cen_n    ;
    assign  output_wen                          =(csr_output_sram_en)   ? axi_output_sram_wen_i     : local_output_wen      ;
    assign  output_addr                         =(csr_output_sram_en)   ? axi_output_sram_addr_i    : local_output_addr     ;
    assign  output_data_in                      =(csr_output_sram_en)   ? axi_output_sram_data_in_i : local_output_data_in  ;

    assign  input_cen_n                         =(csr_input_sram_en )   ? axi_input_sram_cen_n_i    : local_input_cen_n     ;
    assign  input_wen                           =(csr_input_sram_en )   ? axi_input_sram_wen_i      : '0                    ;
    assign  input_addr                          =(csr_input_sram_en )   ? axi_input_sram_addr_i     : local_input_addr      ;
    assign  input_data_in                       =(csr_input_sram_en )   ? axi_input_sram_data_in_i  : '0                    ;

    assign  axi_level0_reg_data_out_o           =level0_data_out                                                            ;
    assign  axi_block_sram_data_out_o           =block_data_out                                                             ;
    assign  axi_output_sram_data_out_o          =output_data_out                                                            ;
    assign  axi_input_sram_data_out_o           =input_data_out                                                             ;

endmodule
    