/*
    通过保存在sram_block的20*20遮挡矩阵筛选anchor，把通过筛选的anchor及其信息保存在sram
    由于读取并保存一个anchor全部的坐标和特征需要读写10次，所以每10个时钟周期处理一个anchor
    输入的anchor坐标为fp16，内部用16位定点数计算,最高位表示符号,低6位表示小数
    输入为anchor_addr_start、anchor_addr_end,表示anchor的起始和终止地址; 以及其他必要参数
    

    sram中给mem的赋值部分用于测试，测试完成后删除赋值
*/


parameter DATA_WIDTH=16;
parameter paraxy=16'b1010000000000; // 16位的paraxy
parameter sub_paraxy=16'b10100000000; // 16位的paraxy
parameter subparaxy_int=16'b10100;
`timescale 1ns / 1ps
module anchor_shield #(
    parameter ANCHOR_DATA_WIDTH = 4*DATA_WIDTH,  // 3*fp16 (每个anchor 16位x3)
    parameter ANCHOR_ADDR_WIDTH = 7,  // 支持1024 anchor
    parameter ANCHOR_DEPTH      = 1024,

    parameter BLOCK_DATA_WIDTH  = 64,   // 每格block 8位
    parameter BLOCK_ADDR_WIDTH  = 6,   // 20x20 block=400
    parameter BLOCK_DEPTH       = 400
)(
    input  logic clk,
    input  logic rst_n,

    // 控制信号
    input  logic start,
    input  logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_end, // 地址终止位置
    input  logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start, // 地址起始位置

    // 参数
    input  logic [2:0] block_x_idx,
    input  logic [2:0] block_y_idx,
    input  logic [DATA_WIDTH-1:0] fx,
    input  logic [DATA_WIDTH-1:0] fy,
    input  logic [DATA_WIDTH-1:0] zlength,
    input  logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics, 
    input  logic [7:0] delay,
    // 与外部交互的sram_anchor数据访问接口
    output logic                         anchor_cen_n,
    output logic                         anchor_wen,
    output logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_final,
    output logic [ANCHOR_DATA_WIDTH-1:0] anchor_data,
    

    // 与外部交互的sram_block数据访问接口
    output logic [BLOCK_ADDR_WIDTH-1:0]  block_addr,
    output logic                         block_cen_n,
    output logic                         block_wen,
    output logic [BLOCK_DATA_WIDTH-1:0]  block_data_in,
    input logic [BLOCK_DATA_WIDTH-1:0]  block_data_out_pre,

    output logic                         anchor_cen_n_save,
    output logic                         anchor_wen_save,
    output logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_save,
    output logic [ANCHOR_DATA_WIDTH-1:0] anchor_save_data_in,
    // 最终输出
    output logic done,
    output logic mask //输出1表示有效anchor，未被遮挡
    
);

    // ============== 内部SRAM接口信号 ==============
    // Anchor SRAM
    
    // Block_occluded SRAM
    logic self_rstn;
    logic rstn;
    
    logic [1:0] next_state;
    logic done_prepare;
    logic done_compute;
    logic [2:0] count_prepare;
    logic [2:0] x_idx;
    logic [2:0] y_idx;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start_stored,anchor_addr_end_stored,anchor_addr_end_stored_a;
    logic [DATA_WIDTH-1:0] zlength_stored,zblock,fx_stored,fy_stored;
    logic [7:0] delay_stored;
    logic [1:0] state;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr;
    logic [DATA_WIDTH-1:0] x_factor;
    logic [DATA_WIDTH-1:0] y_factor;
    logic [DATA_WIDTH-1:0] pdfx,pdfy;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_feat_addr,dx;
    logic [5:0] count_compute;
    logic [DATA_WIDTH-1:0] x_cam_pos,y_cam_pos,z_cam_pos,x_cam_pos_o,y_cam_pos_o,z_cam_pos_o,x_cam_pos_o1,y_cam_pos_o1,z_cam_pos_o1,
            x_cam_pos_o2,y_cam_pos_o2,z_cam_pos_o2,x_cam_pos_o3,y_cam_pos_o3,z_cam_pos_o3;
    logic [DATA_WIDTH-1:0] feature;
    logic last_anchor;
    logic [ANCHOR_ADDR_WIDTH-1:0] delta_addr,anchor_addr_count;
    logic anchor_in_frustum;
    logic [DATA_WIDTH-1:0] z_new_pos1;
    logic [DATA_WIDTH-1:0] x_new_pos,y_new_pos,z_new_pos,x_new_pos_to_store,y_new_pos_to_store;
    logic [7:0] z_new_pos_to_store;
    logic effective;
    logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics_int,viewmetrics_int_stored;
    logic start_delay;
    logic [DATA_WIDTH-1:0] xblock,yblock;
    logic [DATA_WIDTH-1:0] x_new_pos_to_store_delay;
    logic [9-2:0] z_new_pos_to_store_delay1,z_new_pos_to_store_delay2,z_new_pos_to_store_delay3;
    logic effective_delay1, effective_delay2,effective_delay3;
    logic block_cen_n_delay;
    logic [9:0] rest;
    logic [DATA_WIDTH-1:0] mid1;
    logic should_new;
    logic [9-1:0] block_data_out_new,block_data_out;
    logic is_first;
    logic [3:0] is_position;
    logic position_en,mask_pre;
    logic [4:0] anchor_save_count;
    logic [4:0] done_count;
    logic anchor_done;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_count_save_start;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_count_save_delta,addr1,addr2;
    logic [4:0] restx,restx_pre,restx_pre2,numx,step,partial_x_new_pos_to_store_delay;
    logic [10:0] rest_x_pos_delay;
    logic [6:0][8:0] data_out_all,data_out_all_store;
    logic [63:0] data_in_all;
    logic aa;
    logic diff,diff1;
    logic [ANCHOR_DATA_WIDTH-1:0] data_reg;
    logic state_is_10;
    assign rstn=rst_n&&self_rstn;
    assign anchor_wen_save=~anchor_cen_n_save;
    
    //状态机
    always @(posedge clk) begin
        if (~rstn) begin
            state<=0;
        end else begin
            state<=next_state;
        end      
    end
    always @(*) begin
        case (state)
            2'b00: next_state=start ? 2'b01 : 2'b00;
            2'b01: next_state=done_prepare ? 2'b10 : 2'b01;
            2'b10: next_state=done_compute ? 2'b00 : 2'b10;
            default: next_state=2'b00;
        endcase
    end
    
    //1.prepare
    
    always @(posedge clk) begin
        if (~rstn) begin
            count_prepare<=0;
        end else if (state==2'b01) begin
            count_prepare<=count_prepare+1;
        end else if (done_prepare) begin
            count_prepare<=0;
        end else begin
            count_prepare<=count_prepare;
        end
    end
    assign done_prepare=(count_prepare==1);

   
    always @(posedge clk) begin
        if (~rstn) begin
            x_idx<=3'b0;
            y_idx<=3'b0;
            anchor_addr_start_stored<=0;
            anchor_addr_end_stored<=0;
            //anchor_addr<=0;
            zlength_stored<=0;
            fx_stored<=0;
            fy_stored<=0;
            delay_stored<=0;
        end else begin
            if (start) begin
                x_idx<=block_x_idx;
                y_idx<=block_y_idx;
                //anchor_addr<=anchor_addr_start;
                anchor_addr_start_stored<=anchor_addr_start;
                anchor_addr_end_stored<=anchor_addr_end;
                zlength_stored<=zlength;
                fx_stored<=fx;
                fy_stored<=fy;
                delay_stored<=delay;
            end else begin
                //anchor_addr<=anchor_addr_start;
                anchor_addr_start_stored<=anchor_addr_start_stored;
                anchor_addr_end_stored<=anchor_addr_end_stored;
                zlength_stored<=zlength_stored;
                fx_stored<=fx_stored;
                fy_stored<=fy_stored;
                delay_stored<=delay_stored;
            end
        end
    end
    
    lut_tan x1(clk,rstn,fx_stored,x_factor);
    lut_tan y1(clk,rstn,fy_stored,y_factor);
    divide d0 (
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(zlength_stored),
        .b(paraxy),
        .c(zblock)
    );
    
    
    divide d1(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(paraxy),
        .b(x_factor), // 计算x方向的分块
        .c(pdfx)
    );
    divide d2(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(paraxy),
        .b(y_factor), // 计算x方向的分块
        .c(pdfy)
    );
    //2.compute
    
    always @(posedge clk) begin
        if (~rstn) begin
            count_compute<=0;
        end else if (state==2'b10&&last_anchor) begin
            count_compute<=count_compute+1;
        end else if (done_compute)begin
            count_compute<=0;
        end else begin
            count_compute<=count_compute;
        end
        if (~rstn) begin
            done<=0;
            self_rstn<=1;
        end else if (done_compute) begin
            done<=1;
            self_rstn<=0;
        end
    end
    assign done_compute=(count_compute==11);
        //2.1 get anchor
 
    
    
    assign dx=(anchor_addr_count<3) ? 1:0;
    assign anchor_feat_addr=((anchor_addr-anchor_addr_start_stored)>=10)||(anchor_addr_count>7) ? anchor_addr+anchor_addr_count-12-dx : 0;
    
    assign anchor_addr_final= (anchor_addr_count==0) ? anchor_addr : anchor_feat_addr;

    
    assign {x_cam_pos_o,y_cam_pos_o,z_cam_pos_o,feature}=anchor_data; 
    
    always @(posedge clk) begin
        if (~rstn) begin
            //delta_addr<=0;
            anchor_addr_count<=0;
        end else begin
            if (anchor_addr_count==9) begin
                anchor_addr_count<=0;
                //delta_addr<=0;
            end else if (state!=2'b10) begin
                anchor_addr_count<=0;
                //delta_addr<=0;
            end else begin
                anchor_addr_count<=anchor_addr_count+1;
                //delta_addr<=0;
            end
        end
    end
    assign delta_addr=(anchor_addr_count==9)  ? 10:0;
    always @(posedge clk) begin
        if (~rstn) begin
            last_anchor<=0;
            anchor_addr<=0;
            anchor_cen_n<=1;
            anchor_wen<=0;
        end else begin
            if (start) begin
                anchor_addr<=anchor_addr_start;
            end
            else if (anchor_addr>=anchor_addr_end_stored&&state==2'b10) begin
                last_anchor<=1;
                anchor_cen_n<=0;
                anchor_wen<=0;
                anchor_addr<=anchor_addr+delta_addr;
            end else if (state==2'b10) begin
                anchor_addr<=anchor_addr+delta_addr;
                anchor_cen_n<=0;
                anchor_wen<=0;
                last_anchor<=0;
            end else begin
                anchor_cen_n<=(state==2'b01) ? 0 : 1;
                last_anchor<=0;
            end
        end
    end
        //2.2 计算视锥体网格及判断是否在视锥体内
    
    fp_to_int_a #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst (
        .clk(clk),
        .rstn(rstn),
        .a(z_cam_pos_o), // 16位的z坐标
        .c(z_cam_pos_o1) // 16位的z坐标
    );
    fp_to_int_a #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst2 (
        .clk(clk),
        .rstn(rstn),
        .a(x_cam_pos_o), // 16位的x坐标
        .c(x_cam_pos_o1) // 16位的x坐标
    );
    fp_to_int_a #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst3 (
        .clk(clk),
        .rstn(rstn),
        .a(y_cam_pos_o), // 16位的y坐标
        .c(y_cam_pos_o1) // 16位的y坐标
    );
    
  
    
    always @(posedge clk) begin
        if (~rstn) begin
            start_delay<=0;
            viewmetrics_int_stored<=0;
        end else if (start_delay) begin
            start_delay<=0;
            viewmetrics_int_stored<=viewmetrics_int;
        end else begin
            start_delay<=start;
            viewmetrics_int_stored<=viewmetrics_int_stored;
        end
    end 
    
    viewmetrics_fp_int viewmetrics_fp_int_inst ( 
        .clk(clk),
        .rstn(rstn),
        .viewmetrics(viewmetrics), // 视锥体的变换矩阵
        .viewmetrics_int(viewmetrics_int)
    );
    view_trans vt(
        .clk(clk),
        .rstn(rstn),
        .viewmetrics(viewmetrics_int_stored), // 视锥体的变换矩阵
        .x(x_cam_pos_o1),
        .y(y_cam_pos_o1),
        .z(z_cam_pos_o1),
        .xo(x_cam_pos),
        .yo(y_cam_pos),
        .zo(z_cam_pos)
    );
    compute_new_pos compute_new_pos_inst(
        .clk(clk),
        .rst_n(rstn),
        .en(state==2'b10),
        .x(x_cam_pos),
        .y(y_cam_pos),
        .z(z_cam_pos),
        .pdfx(pdfx),  
        .pdfy(pdfy),
        .zblock(zblock),
        .x_idx(x_idx),
        .y_idx(y_idx),
        .x_new_pos(x_new_pos),
        .y_new_pos(y_new_pos),
        .z_new_pos(z_new_pos),
        .effective(effective)
    );
        //2.3：计算小视锥体内的坐标
    
    lut_block_addr lb1(
        .idx(x_idx),
        .final_out(xblock)
    );
    lut_block_addr lb2(
        .idx(y_idx),
        .final_out(yblock) 
    );
    assign state_is_10=(state==2'b10);
    add_a a1 (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_10),
        .a(x_new_pos>>6),
        .b(xblock), // 计算x方向的分块
        .c(x_new_pos_to_store)
    );
    add_a a2(
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_10),
        .a(y_new_pos>>6),
        .b(yblock), // 计算y方向的分块
        .c(y_new_pos_to_store)
    );
    always @(posedge clk) begin
        if (~rstn) begin
            z_new_pos_to_store<=0;
        end else begin
            z_new_pos_to_store<=z_new_pos[13:6];
        end
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            effective_delay1<=0;
            effective_delay2<=0;
            effective_delay3<=0;
            x_new_pos_to_store_delay<=0;
            z_new_pos_to_store_delay1<=0;
            z_new_pos_to_store_delay2<=0;
        end else begin
            effective_delay1<=effective;
            effective_delay2<=effective_delay1;
            effective_delay3<=effective_delay2;
            x_new_pos_to_store_delay<=x_new_pos_to_store;
            z_new_pos_to_store_delay1<=z_new_pos_to_store;
            z_new_pos_to_store_delay2<=z_new_pos_to_store_delay1;
            z_new_pos_to_store_delay3<=z_new_pos_to_store_delay2;

        end
    end
        //2.4：将计算结果存入block_occluded
    assign block_cen_n=!(state==2'b10&&effective_delay3);
    assign block_wen=0;
    assign block_data_in=64'b0;
    
    always @(posedge clk) begin
        if (~rstn) begin
            block_cen_n_delay<=0;
        end else begin
            block_cen_n_delay<=block_cen_n;
        end
    end
    
    
    multiple_simple m1(
        .clk(clk),
        .rst_n(rstn),
        .en(effective_delay1),
        .a(y_new_pos_to_store),
        .b(16'b11), // 8位的block数据
        .c(mid1)
    );
    add_simple a3(
        .clk(clk),
        .rst_n(rstn),
        .en(effective_delay2),
        .a(mid1),
        .b({11'b0,numx}),
        .c({rest,block_addr})
    );
    
    assign block_data_out_new=(!block_cen_n_delay) ? block_data_out : 0;
    assign should_new=(block_data_out_new[9-2:0]>=z_new_pos_to_store_delay3+delay_stored)||(block_data_out_new[9-1]==0);
    
    always @(posedge clk) begin
        if (~rstn) begin
            is_first<=0;
            is_position<=0;
        end else if (is_first==0&&is_position==14) begin
            is_first<=1;
            is_position<=0;
        end else if (is_first==1&&is_position==9) begin
            is_first<=1;
            is_position<=0;
        end else if (state==2'b01) begin
            is_first<=0;
            is_position<=1;
        end else begin
            is_first<=is_first;
            is_position<=is_position+1;
        end
    end
    
    assign position_en=(is_first&&(is_position==9))||((~is_first)&&(is_position==14));
    always @(posedge clk) begin
        if (~rstn) begin
            mask_pre<=0;
        end else begin
            if (should_new) begin
                mask_pre<=1;
            end else begin
                mask_pre<=0;
            end
        end
    end
   assign mask=mask_pre||(~position_en);

   
    always @(posedge clk) begin
        if (~rstn) begin
            anchor_save_count<=0;
        end else if (anchor_save_count==11) begin
            anchor_save_count<=0;
        end else if (mask==0) begin
            anchor_save_count<=1;
        end else if (anchor_save_count!=0) begin
            anchor_save_count<=anchor_save_count+1;
        end else begin
            anchor_save_count<=0;
        end
    end
    assign anchor_cen_n_save=((anchor_save_count!=0)&&(anchor_save_count<11))||(anchor_addr_count_save_start<10) ? 1 : 0;
    
    
    always @(posedge clk) begin
        if (~rstn) begin
            done_count<=0;
        end else if (anchor_feat_addr!=anchor_addr_final&&(state!=2'b01)) begin
            done_count<=1;
        end else if (done_count!=0) begin
            done_count<=done_count+1;
        end else begin
            done_count<=0;
        end
    end
    
    assign anchor_done=(done_count==3&&anchor_addr>anchor_addr_start_stored);
    
    always @(posedge clk) begin
        if (~rstn) begin
            anchor_addr_count_save_start<=0;
        end else if (anchor_done&&mask) begin
            anchor_addr_count_save_start<=anchor_addr_count_save_start+10;
        end else begin
            anchor_addr_count_save_start<=anchor_addr_count_save_start;
        end
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            anchor_addr_count_save_delta<=0;
        end else if (anchor_done&&mask) begin
            anchor_addr_count_save_delta<=0;
        end else if (anchor_feat_addr!=anchor_addr_final)begin
            anchor_addr_count_save_delta<=anchor_addr_count_save_delta;
        end else begin
            anchor_addr_count_save_delta<=anchor_addr_count_save_delta+1;
        end
    end

    
    assign {aa,data_out_all[6],data_out_all[5],data_out_all[4],data_out_all[3],data_out_all[2],data_out_all[1],data_out_all[0]}=block_data_out_pre;
    assign block_data_out=data_out_all[restx];
    
    
    assign {rest_x_pos_delay,partial_x_new_pos_to_store_delay}=x_new_pos_to_store_delay;
    always @(*) begin
        if (partial_x_new_pos_to_store_delay<7) begin
            restx_pre=partial_x_new_pos_to_store_delay;
            numx=0;
        end else if (partial_x_new_pos_to_store_delay<14) begin
            restx_pre=partial_x_new_pos_to_store_delay-7;
            numx=1;
        end else begin
            restx_pre=partial_x_new_pos_to_store_delay-14;
            numx=2;
        end
    end
    always @(posedge clk) begin
        if (~rstn) begin
            restx<=0;
            restx_pre2<=0;
        end else begin
            restx<=restx_pre2;
            restx_pre2<=restx_pre;
        end
    end

    
    shift_reg_1 #(
        .data_width(ANCHOR_DATA_WIDTH)
    ) anchor_data_save_reg (
        .clk(clk),
        .rstn(rstn),
        .move(anchor_addr_count==1),
        .in(anchor_data),
        .out(data_reg)
    );
    
    assign diff=(anchor_feat_addr==anchor_addr_final);
    always @(posedge clk) begin
        if (~rstn) begin
            diff1<=0;
        end else begin
            diff1<=diff;
        end
    end
    assign addr1=(anchor_addr_count_save_start!=0) ? anchor_addr_count_save_start+anchor_addr_count_save_delta-9 : 0;
    assign addr2=(diff1) ? addr1 : anchor_addr_count_save_start-10;
    assign anchor_addr_save=addr2;
    assign anchor_save_data_in=(diff1) ? anchor_data : data_reg;
endmodule






module multiple_a(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] c
);
    logic [5:0] x;
    always @(posedge clk) begin
        if (~rst_n) begin
            c<=0;
        end else if (en) begin 
            c[DATA_WIDTH-1]<=a[DATA_WIDTH-1]^b[DATA_WIDTH-1];
            {c[DATA_WIDTH-2:0],x}<={6'b0,a[DATA_WIDTH-2:0]}*{6'b0,b[DATA_WIDTH-2:0]};
            
        end else begin
            c<=0;
        end
    end
endmodule

module multiple_simple(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] c
);
    logic [5:0] x;
    always @(posedge clk) begin
        if (~rst_n) begin
            c<=0;
        end else if (en) begin 
            c<=a*b;
        end else begin
            c<=0;
        end
    end
endmodule

module add_simple(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] c
);
    logic [5:0] x;
    always @(posedge clk) begin
        if (~rst_n) begin
            c<=0;
        end else if (en) begin 
            c<=a+b;
            
        end else begin
            c<=0;
        end
    end
endmodule

module divide(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] c
);
    logic sign;
    logic [DATA_WIDTH-2+6:0] full;
    logic [DATA_WIDTH-2:0] rest;
    logic [5:0] resta;
    always @(posedge clk) begin
        if (~rst_n) begin
            c<=0;
        end else if (en) begin 
            
            {resta,c[DATA_WIDTH-2:0]}<={a[DATA_WIDTH-2:0],6'b0}/{6'b0,b[DATA_WIDTH-2:0]};
            
            c[DATA_WIDTH-1]<=a[DATA_WIDTH-1]^b[DATA_WIDTH-1];
            
        end else begin
            c<=0;
        end
    end
endmodule

module lut_block_addr(
    input logic [2:0] idx,
    output logic [DATA_WIDTH-1:0] final_out
);
    logic [DATA_WIDTH-1:0] out;
    always @(*) begin
        case (idx)
            3'b000: out=16'h0;
            3'b001: out=16'h14;
            3'b010: out=16'h28;
            3'b011: out=16'h3c;
            3'b100: out=16'h50;
            3'b101: out=16'h64;
            3'b110: out=16'h78;
            3'b111: out=16'h8c;
            default: out=16'h0;
    endcase
    final_out={1'b1,out[DATA_WIDTH-2:0]};
    end
endmodule
module add_a #(
    parameter data_width=DATA_WIDTH
)(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [data_width-1:0] a,
    input logic [data_width-1:0] b,
    output logic [data_width-1:0] c
);
    always @(posedge clk) begin
        if (~rst_n) begin
            c<=0;
        end else if (en) begin 
            if (a[data_width-1]==b[data_width-1]) begin
                c<={a[data_width-1],a[data_width-2:0]+b[data_width-2:0]};
            end else begin
                c<=(a[data_width-2:0]>b[data_width-2:0]) ? 
                    {a[data_width-1],a[data_width-2:0]-b[data_width-2:0]} : {b[data_width-1],b[data_width-2:0]-a[data_width-2:0]};
            end
        end else begin
            c<=0;
        end
    end
endmodule


module lut_tan(
    input logic clk,
    input logic rst_n,
    input logic [DATA_WIDTH-1:0] a,
    output logic [DATA_WIDTH-1:0] b
);
    always @(posedge clk) begin
        if (~rst_n) begin
            b<=0;
        end else begin 
            case (a>>1)
                16'b0000000000000000: b<=16'b0000000000000000;
16'b0000000000000001: b<=16'b0000000000000001;
16'b0000000000000010: b<=16'b0000000000000010;
16'b0000000000000011: b<=16'b0000000000000011;
16'b0000000000000100: b<=16'b0000000000000100;
16'b0000000000000101: b<=16'b0000000000000101;
16'b0000000000000110: b<=16'b0000000000000110;
16'b0000000000000111: b<=16'b0000000000000111;
16'b0000000000001000: b<=16'b0000000000001000;
16'b0000000000001001: b<=16'b0000000000001001;
16'b0000000000001010: b<=16'b0000000000001010;
16'b0000000000001011: b<=16'b0000000000001011;
16'b0000000000001100: b<=16'b0000000000001100;
16'b0000000000001101: b<=16'b0000000000001101;
16'b0000000000001110: b<=16'b0000000000001110;
16'b0000000000001111: b<=16'b0000000000001111;
16'b0000000000010000: b<=16'b0000000000010000;
16'b0000000000010001: b<=16'b0000000000010001;
16'b0000000000010010: b<=16'b0000000000010010;
16'b0000000000010011: b<=16'b0000000000010100;
16'b0000000000010100: b<=16'b0000000000010101;
16'b0000000000010101: b<=16'b0000000000010110;
16'b0000000000010110: b<=16'b0000000000010111;
16'b0000000000010111: b<=16'b0000000000011000;
16'b0000000000011000: b<=16'b0000000000011001;
16'b0000000000011001: b<=16'b0000000000011010;
16'b0000000000011010: b<=16'b0000000000011100;
16'b0000000000011011: b<=16'b0000000000011101;
16'b0000000000011100: b<=16'b0000000000011110;
16'b0000000000011101: b<=16'b0000000000011111;
16'b0000000000011110: b<=16'b0000000000100000;
16'b0000000000011111: b<=16'b0000000000100010;
16'b0000000000100000: b<=16'b0000000000100011;
16'b0000000000100001: b<=16'b0000000000100100;
16'b0000000000100010: b<=16'b0000000000100110;
16'b0000000000100011: b<=16'b0000000000100111;
16'b0000000000100100: b<=16'b0000000000101000;
16'b0000000000100101: b<=16'b0000000000101010;
16'b0000000000100110: b<=16'b0000000000101011;
16'b0000000000100111: b<=16'b0000000000101101;
16'b0000000000101000: b<=16'b0000000000101110;
16'b0000000000101001: b<=16'b0000000000110000;
16'b0000000000101010: b<=16'b0000000000110001;
16'b0000000000101011: b<=16'b0000000000110011;
16'b0000000000101100: b<=16'b0000000000110101;
16'b0000000000101101: b<=16'b0000000000110110;
16'b0000000000101110: b<=16'b0000000000111000;
16'b0000000000101111: b<=16'b0000000000111010;
16'b0000000000110000: b<=16'b0000000000111100;
16'b0000000000110001: b<=16'b0000000000111110;
16'b0000000000110010: b<=16'b0000000001000000; //tan45
16'b0000000000110011: b<=16'b0000000001000001;
16'b0000000000110100: b<=16'b0000000001000100;
16'b0000000000110101: b<=16'b0000000001000110;
16'b0000000000110110: b<=16'b0000000001001000;
16'b0000000000110111: b<=16'b0000000001001010;
16'b0000000000111000: b<=16'b0000000001001101;
16'b0000000000111001: b<=16'b0000000001001111;
16'b0000000000111010: b<=16'b0000000001010010;
16'b0000000000111011: b<=16'b0000000001010100;
16'b0000000000111100: b<=16'b0000000001010111;
16'b0000000000111101: b<=16'b0000000001011010;
16'b0000000000111110: b<=16'b0000000001011101;
16'b0000000000111111: b<=16'b0000000001100000;
16'b0000000001000000: b<=16'b0000000001100100;
16'b0000000001000001: b<=16'b0000000001100111;
16'b0000000001000010: b<=16'b0000000001101011;
16'b0000000001000011: b<=16'b0000000001101111;
16'b0000000001000100: b<=16'b0000000001110011;
16'b0000000001000101: b<=16'b0000000001110111;
16'b0000000001000110: b<=16'b0000000001111100;
16'b0000000001000111: b<=16'b0000000010000001;
16'b0000000001001000: b<=16'b0000000010000110;
16'b0000000001001001: b<=16'b0000000010001011;
16'b0000000001001010: b<=16'b0000000010010001;
16'b0000000001001011: b<=16'b0000000010011000;
16'b0000000001001100: b<=16'b0000000010011111;
16'b0000000001001101: b<=16'b0000000010100110;
16'b0000000001001110: b<=16'b0000000010101110;
16'b0000000001001111: b<=16'b0000000010110111;
16'b0000000001010000: b<=16'b0000000011000001;
16'b0000000001010001: b<=16'b0000000011001011;
16'b0000000001010010: b<=16'b0000000011010111;
16'b0000000001010011: b<=16'b0000000011100100;
16'b0000000001010100: b<=16'b0000000011110010;
16'b0000000001010101: b<=16'b0000000100000011;
16'b0000000001010110: b<=16'b0000000100010101;
16'b0000000001010111: b<=16'b0000000100101010;
16'b0000000001011000: b<=16'b0000000101000011;
16'b0000000001011001: b<=16'b0000000101011111;
16'b0000000001011010: b<=16'b0000000110000001;
16'b0000000001011011: b<=16'b0000000110101011;
16'b0000000001011100: b<=16'b0000000111011101;
16'b0000000001011101: b<=16'b0000001000011101;
16'b0000000001011110: b<=16'b0000001001110001;
16'b0000000001011111: b<=16'b0000001011100011;
16'b0000000001100000: b<=16'b0000001110000110;
16'b0000000001100001: b<=16'b0000010010000111;
16'b0000000001100010: b<=16'b0000011001010010;
16'b0000000001100011: b<=16'b0000101001110011;
16'b0000000001100100: b<=16'b0001111000100010;
default: b<=16'b0001111000100010;
            endcase
        end
    end
endmodule





module compute_new_pos(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] x,
    input logic [DATA_WIDTH-1:0] y,
    input logic [DATA_WIDTH-1:0] z,
    input logic [DATA_WIDTH-1:0] pdfx,  
    input logic [DATA_WIDTH-1:0] pdfy,
    input logic [DATA_WIDTH-1:0] zblock,
    input logic [2:0] x_idx,
    input logic [2:0] y_idx,
    output logic [DATA_WIDTH-1:0] x_new_pos,
    output logic [DATA_WIDTH-1:0] y_new_pos,
    output logic [DATA_WIDTH-1:0] z_new_pos,
    output logic effective
);
    logic [DATA_WIDTH-1:0] xd,yd,zfx,zfy,x_new_pos_pre1,y_new_pos_pre1,x_new_pos_pre2,y_new_pos_pre2,z_new_pos_pre2,z1,z2;
    divide d1(clk, rst_n, en, x, z, xd);
    divide d2(clk, rst_n, en, y, z, yd);
    multiple_a m3(clk, rst_n, en, xd, pdfx, x_new_pos_pre1);
    multiple_a m4(clk, rst_n, en, yd, pdfy, y_new_pos_pre1);
    add_a a1(clk, rst_n, en, x_new_pos_pre1, paraxy, x_new_pos_pre2);
    add_a a2(clk, rst_n, en, y_new_pos_pre1, paraxy, y_new_pos_pre2);

    divide d3(clk, rst_n, en, z2, zblock, z_new_pos_pre2);
    always @(posedge clk) begin
        if (~rst_n) begin
            z1<=0;
        end else begin
            z1<=z;
        end
    end
    always @(posedge clk) begin
        if (~rst_n) begin
            z2<=0;
        end else begin
            z2<=z1;
        end
    end
    in_frustrum_judge in_frustrum_judge_inst(
        .x_idx(x_idx),
        .y_idx(y_idx),
        .x(x_new_pos_pre2),
        .y(y_new_pos_pre2),
        .z(z_new_pos_pre2),
        .in(effective)
    );
    floor f1(
        .a(x_new_pos_pre2),
        .b(x_new_pos)
    );
    floor f2(
        .a(y_new_pos_pre2),
        .b(y_new_pos)
    ); 
    floor f3(
        .a(z_new_pos_pre2),
        .b(z_new_pos)
    );
endmodule

module in_frustrum_judge(
    input logic [2:0] x_idx,
    input logic [2:0] y_idx,
    input logic [DATA_WIDTH-1:0] x,
    input logic [DATA_WIDTH-1:0] y,
    input logic [DATA_WIDTH-1:0] z,
    output logic in
);
    logic p1,p2,p3,p4,p5,p6;
    bigger_a #(
        .width(DATA_WIDTH)
    ) x_bigger (
        .a(x),
        .b({13'b0,x_idx}*sub_paraxy),
        .c(p1)
    );
    bigger_a #(
        .width(DATA_WIDTH)
    ) x0_bigger (
        .a(x),
        .b({13'b0,x_idx+1'b1}*sub_paraxy),
        .c(p2)
    );
    bigger_a #(
        .width(DATA_WIDTH)
    ) y_bigger (
        .a(y),
        .b({13'b0,y_idx}*sub_paraxy),
        .c(p3)
    );
    bigger_a #(
        .width(DATA_WIDTH)
    ) y0_bigger (
        .a(y),
        .b({13'b0,y_idx+1'b1}*sub_paraxy),
        .c(p4)
    );
    
    bigger_a #(
        .width(DATA_WIDTH)
    ) z_bigger (
        .a(z),
        .b(16'b0),
        .c(p5)
    );
    bigger_a #(
        .width(DATA_WIDTH)
    ) z0_bigger (
        .a(z),
        .b(paraxy),
        .c(p6)
    );
    assign in = p1&&(~p2) && p3 && (~p4) && p5 && (~p6);
    
endmodule

module bigger_a #(
    parameter width
)(
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    output logic c
);
    logic d;
    assign d=a>=b;
    always @(*) begin
        if (a[width-1]==1'b0&&b[width-1]==1'b0) begin
            c=d; 
        end else if (a[width-1]==1'b1&&b[width-1]==1'b1) begin
            c=~d;
        end else if (a[width-1]==1'b0&&b[width-1]==1'b1) begin
            c=1;
        end else begin 
            c=0; 
        end
    end
    
endmodule

module floor (
    input logic [DATA_WIDTH-1:0] a,
    output logic [DATA_WIDTH-1:0] b
);
    assign b={a[DATA_WIDTH-1:6], 6'b0}; 
endmodule

module fp_to_int_a #(
    parameter DATA_WIDTH=16
)(
    input  logic                   clk,
    input  logic                   rstn,
    input  logic [DATA_WIDTH-1:0]  a,  // fp16输入
    output logic [DATA_WIDTH-1:0]  c   // [15]sign | [14:0]abs(定点)
);

    // 拆解fp16
    logic        sign;
    logic [4:0]  exponent;
    logic [9:0]  mantissa;

    assign sign     = a[15];
    assign exponent = a[14:10];
    assign mantissa = a[9:0];

    // 处理尾数：加上隐含1
    logic [10:0] mantissa_full;
    assign mantissa_full = (exponent == 5'd0) ? {1'b0, mantissa} : {1'b1, mantissa};

    // 计算实际移位量
    // exp_real = exponent - 15 + 6 - 10 = exponent - 19
    logic [5:0] shift_amt;
    logic shift_left;
    always @(*) begin
        if(exponent >= 5'd19) begin
            shift_amt = exponent - 5'd19;
            shift_left = 1'b1;
        end else begin
            shift_amt = 5'd19 - exponent;
            shift_left = 1'b0;
        end
    end
    logic [25:0] mantissa_full_ext;
    assign mantissa_full_ext = {{15{1'b0}}, mantissa_full};
    // 对齐到[14:0]输出
    logic [25:0] aligned;
    always @(*) begin
        if(shift_left)
            aligned = mantissa_full_ext << shift_amt;
        else
            aligned = mantissa_full_ext >> shift_amt;
    end

    // 输出绝对值，只取15位
    logic [14:0] abs_val;
    always @(*) begin
        // 溢出保护，若高位非零则输出最大
        if(aligned[25:15] != 11'b0)
            abs_val = 15'h7fff;
        else
            abs_val = aligned[14:0];
    end

    // 输出寄存器，最高位为符号，其余为绝对值
    always @(posedge clk) begin
        if (!rstn)
            c <= 16'd0;
        else
            c <= {sign, abs_val};
    end

endmodule

module viewmetrics_fp_int(
    input logic clk,
    input logic rstn,
    input logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics,
    output logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics_int
);
    genvar i, j;
    generate
        for (i = 0; i < 4; i = i + 1) begin : row
            for (j = 0; j < 4; j = j + 1) begin : col
                fp_to_int_a #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) fp_to_int_inst (
                    .clk(clk),
                    .rstn(rstn),
                    .a(viewmetrics[i][j]),
                    .c(viewmetrics_int[i][j])
                );
            end
        end
    endgenerate
endmodule

module view_trans (
    input logic clk,
    input logic rstn,
    input logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics,
    input logic [DATA_WIDTH-1:0] x,
    input logic [DATA_WIDTH-1:0] y,
    input logic [DATA_WIDTH-1:0] z,
    output logic [DATA_WIDTH-1:0] xo,
    output logic [DATA_WIDTH-1:0] yo,
    output logic [DATA_WIDTH-1:0] zo
);
    logic [DATA_WIDTH-1:0] mulx1,mulx2,mulx3,mulx4,addx1,addx2;
    logic [DATA_WIDTH-1:0] muly1,muly2,muly3,muly4,addy1,addy2;
    logic [DATA_WIDTH-1:0] mulz1,mulz2,mulz3,mulz4,addz1,addz2;
    multiple_a m1(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[0][0]),
        .b(x),
        .c(mulx1)
    );
    multiple_a m2(
        .clk(clk),
        .rst_n(rstn),   
        .en(1'b1),
        .a(viewmetrics[0][1]),
        .b(y),
        .c(muly1)
    );
    multiple_a m3(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),  
        .a(viewmetrics[0][2]),
        .b(z), 
        .c(mulz1)
    );
    multiple_a m4(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[0][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(mulx2)
    );
    multiple_a m5(
        .clk(clk), 
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[1][0]),  
        .b(x),
        .c(muly2)   
    );
    multiple_a m6(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1), 
        .a(viewmetrics[1][1]),
        .b(y),
        .c(mulz2)
    );
    multiple_a m7(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[1][2]),    
        .b(z),
        .c(mulx3)
    );
    multiple_a m8(
        .clk(clk),      
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[1][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(muly3)
    );
    multiple_a m9(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[2][0]),  
        .b(x),
        .c(mulz3)
    );
    multiple_a m10(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[2][1]),
        .b(y),  
        .c(mulx4)
    );
    multiple_a m11(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[2][2]),
        .b(z),
        .c(muly4)
    );
    multiple_a m12(
        .clk(clk),  
        .rst_n(rstn),
        .en(1'b1),
        .a(viewmetrics[2][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(mulz4)
    );
    add_a a1(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(mulx1),
        .b(mulx2),
        .c(addx1)
    );
    
    add_a a2(
        .clk(clk),
        .rst_n(rstn),   
        .en(1'b1),
        .a(muly1),
        .b(muly2),  
        .c(addy1)
    );
    add_a a3(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(mulz1),
        .b(mulz2),
        .c(addz1)
    );
    add_a a4(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(mulx3),
        .b(mulx4),  
        .c(addx2)
    );
    add_a a5(
        .clk(clk),
        .rst_n(rstn),       
        .en(1'b1),
        .a(muly3),
        .b(muly4),
        .c(addy2)
    );
    add_a a6(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(mulz3),
        .b(mulz4),  
        .c(addz2)
    );
     add_a a7(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(addx1),
        .b(addx2),
        .c(xo)
    );
    add_a a8(
        .clk(clk),  
        .rst_n(rstn),
        .en(1'b1),
        .a(addy1),
        .b(addy2),
        .c(yo)
    );
    add_a a9(
        .clk(clk),
        .rst_n(rstn),
        .en(1'b1),
        .a(addz1),
        .b(addz2),
        .c(zo)
    );
endmodule

module shift_reg_1 #(
    parameter data_width=48
)(
    input logic clk,
    input logic rstn,
    input logic move,
    input logic [data_width-1:0] in,
    output logic [data_width-1:0] out
);
    logic [1:0][data_width-1:0] register;
    always @(posedge clk) begin
        if (~rstn) begin
            register<=0;
            out<=0;
        end else if (move) begin
            out<=register[1];
            register[1]<=register[0];
            register[0]<=in;
        end else begin
            register<=register;
            out<=register[1];
        end
    end

endmodule
