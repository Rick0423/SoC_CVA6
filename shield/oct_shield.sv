/*
    用于由筛选后的0级anchor建立20*20的遮挡矩阵
    从48位宽的sram_anchor中读取0级anchor坐标(fp16表示)，写入20*20*9的sram_block; 
    由于sram_block需要读一次、写一次(用于比大小确定是否写入)，因此两个周期完成一个anchor的计算
    输入为anchor_addr_start、anchor_addr_end,表示anchor的起始和终止地址; 以及其他必要参数
    输入为fp16, 内部用16位定点数计算,最高位表示符号,低6位表示小数

    376行viewmetrics直接赋值用于测试,测试完成后把数字替换为viewmetrics
    697、629行sram中给mem的赋值部分用于测试，测试完成后删除赋值
*/



module oct_shield #(
    parameter DATA_WIDTH=16,
    parameter paraxy=16'b1010000000000, // 16位的paraxy
    parameter sub_paraxy=16'b10100000000, // 16位的paraxy
    parameter subparaxy_int=16'b10100,
    parameter ANCHOR_DATA_WIDTH = 3*DATA_WIDTH,  // 3*fp16 (每个anchor 16位x3)
    parameter ANCHOR_ADDR_WIDTH = 4,  // 支持1024 anchor
    parameter ANCHOR_DEPTH      = 1024,

    parameter BLOCK_DATA_WIDTH  = 64,   // 每格block 8位
    parameter BLOCK_ADDR_WIDTH  = 6,   // 20x20 block=400
    parameter BLOCK_DEPTH       = 400
)(
    input  logic clk,
    input  logic rst_n,

    // 控制信号
    input  logic start,
    input  logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_end, // 需要读取的anchor数
    input  logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start,
    // 块起始坐标（如3比特指示，实际可扩展为更高位）
    input  logic [2:0] block_x_idx,
    input  logic [2:0] block_y_idx,
    input  logic [DATA_WIDTH-1:0] fx,
    input  logic [DATA_WIDTH-1:0] fy,
    input  logic [DATA_WIDTH-1:0] zlength,
    input  logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics, 

    // 与外部交互的sram_anchor数据访问接口
    output logic anchor_cen_n,
    output logic anchor_wen,
    output logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr,
    
    output logic [ANCHOR_DATA_WIDTH-1:0] anchor_data,
    output logic [BLOCK_ADDR_WIDTH-1:0]  block_addr,
    output logic                         block_cen_n,
    output logic                         block_wen,
    output logic [BLOCK_DATA_WIDTH-1:0]  block_data_in_pre,
    input logic [BLOCK_DATA_WIDTH-1:0]  block_data_out_pre,

    // 处理完成
    output logic done
);

    // ============== 内部SRAM接口信号 ==============
    // Anchor SRAM
    
    // Block_occluded SRAM
    logic self_rstn;
    logic rstn;
    assign rstn=rst_n&&self_rstn;
  
    logic [1:0] state;
    logic [1:0] next_state;
    logic done_prepare;
    logic done_compute;
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
    logic [2:0] count_prepare;
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

    logic [2:0] x_idx;
    logic [2:0] y_idx;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start_stored,anchor_addr_end_stored;
    logic [DATA_WIDTH-1:0] zlength_stored,zblock,fx_stored,fy_stored;
    always @(posedge clk) begin
        if (~rstn) begin
            x_idx<=3'b0;
            y_idx<=3'b0;
            anchor_addr_start_stored<=0;
            anchor_addr_end_stored<=0;
            anchor_addr<=0;
            zlength_stored<=0;
            fx_stored<=0;
            fy_stored<=0;
        end else begin
            if (start) begin
                x_idx<=block_x_idx;
                y_idx<=block_y_idx;
                anchor_addr<=anchor_addr_start;
                anchor_addr_start_stored<=anchor_addr_start;
                anchor_addr_end_stored<=anchor_addr_end;
                zlength_stored<=zlength;
                fx_stored<=fx;
                fy_stored<=fy;
            end
        end
    end
    
    logic [DATA_WIDTH-1:0] x_factor;
    logic [DATA_WIDTH-1:0] y_factor;
    lut_tan_o x1(clk,rstn,fx_stored,x_factor);
    lut_tan_o y1(clk,rstn,fy_stored,y_factor);
    divide_o d0 (
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(zlength_stored),
        .b(paraxy),
        .c(zblock)
    );
    logic [DATA_WIDTH-1:0] pdfx,pdfy;
    divide_o d1(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(paraxy),
        .b(x_factor), // 计算x方向的分块
        .c(pdfx)
    );
    divide_o d2(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(paraxy),
        .b(y_factor), // 计算x方向的分块
        .c(pdfy)
    );
    //2.compute
    logic [5:0] count_compute;
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
    assign done_compute=(count_compute==9);
        //2.1 get anchor

    logic delta_addr;
    always @(posedge clk) begin
        if (~rstn) begin
            delta_addr<=0;
        end else begin
            if (state==2'b10) begin
                delta_addr<=~delta_addr;
            end else begin
                delta_addr<=0;
            end
        end
    end
    
    logic [DATA_WIDTH-1:0] x_cam_pos,y_cam_pos,z_cam_pos;
    assign {x_cam_pos_o,y_cam_pos_o,z_cam_pos_o}=anchor_data;
    logic last_anchor;
    always @(posedge clk) begin
        if (~rstn) begin
            last_anchor<=0;
            anchor_addr<=0;
            anchor_cen_n<=1;
            anchor_wen<=0;
        end else begin
            if (anchor_addr==anchor_addr_end_stored) begin
                last_anchor<=1;
                anchor_cen_n<=1;
                anchor_wen<=0;
            end else if (state==2'b10) begin
                anchor_addr<=anchor_addr+{3'b0,delta_addr};
                anchor_cen_n<=0;
                anchor_wen<=0;
                last_anchor<=0;
            end else begin
                anchor_cen_n<=(next_state==2'b10) ? 0 : 1;
                last_anchor<=0;
            end
        end
    end
        //2.2 计算视锥体网格及判断是否在视锥体内
    logic anchor_in_frustum;
    logic [DATA_WIDTH-1:0] z_new_pos1;
    
    logic [DATA_WIDTH-1:0] x_new_pos,y_new_pos,z_new_pos,x_new_pos_to_store,y_new_pos_to_store;
    logic [7:0] z_new_pos_to_store;
    logic effective;
    logic [DATA_WIDTH-1:0] x_cam_pos_o,y_cam_pos_o,z_cam_pos_o,
                           x_cam_pos_o1,y_cam_pos_o1,z_cam_pos_o1;
    fp_to_int_o #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst (
        .clk(clk),
        .rstn(rstn),
        .a(z_cam_pos_o), // 16位的z坐标
        .c(z_cam_pos_o1) // 16位的z坐标
    );
    fp_to_int_o #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst2 (
        .clk(clk),
        .rstn(rstn),
        .a(x_cam_pos_o), // 16位的x坐标
        .c(x_cam_pos_o1) // 16位的x坐标
    );
    fp_to_int_o #(
        .DATA_WIDTH(DATA_WIDTH)
    ) fp_to_int_inst3 (
        .clk(clk),
        .rstn(rstn),
        .a(y_cam_pos_o), // 16位的y坐标
        .c(y_cam_pos_o1) // 16位的y坐标
    );
    
    logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics_int,viewmetrics_int_stored;
    logic start_delay;
    
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
    
    viewmetrics_fp_int_o viewmetrics_fp_int_inst (
        .clk(clk),
        .rstn(rstn),
        .viewmetrics(256'h3c003c003c003c003c003c003c003c003c003c003c003c003c0051003c003c00), // 视锥体的变换矩阵 用于测试，实际应替换为viewmetrics
        .viewmetrics_int(viewmetrics_int)
    );
    view_trans_o vt(
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
    
    compute_new_pos_o compute_new_pos_inst(
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
    logic [DATA_WIDTH-1:0] xblock,yblock;
    lut_block_addr_o lb1(
        .idx(x_idx),
        .final_out(xblock)
    );
    lut_block_addr_o lb2(
        .idx(y_idx),
        .final_out(yblock) 
    );
    add_o a1 (
        .clk(clk),
        .rst_n(rstn),
        .en(state==2'b10),
        .a(x_new_pos>>6),
        .b(xblock), // 计算x方向的分块
        .c(x_new_pos_to_store)
    );
    add_o a2(
        .clk(clk),
        .rst_n(rstn),
        .en(state==2'b10),
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
        //2.4：将计算结果存入block_occluded
    /*
    sram_block #(
        .data_width(BLOCK_DATA_WIDTH),
        .addr_width(BLOCK_ADDR_WIDTH),
        .depth(BLOCK_DEPTH)
    ) block_occluded_sram (
        .clk(clk),
        .cen_n(block_cen_n),
        .wen(block_wen),
        .addr(block_addr),
        .data_in(block_data_in),
        .data_out(block_data_out)
    );*/
    logic [9:0] rest;
    logic effective_delay1,effective_delay2,effective_delay3,block_cen_n_delay;
    logic [9-2:0] z_new_pos_to_store_delay,z_new_pos_to_store_delay1,z_new_pos_to_store_delay2;
    logic [DATA_WIDTH-1:0] x_new_pos_to_store_delay;
    always @(posedge clk) begin
        if (~rstn) begin
            effective_delay1<=0;
            effective_delay2<=0;
            effective_delay3<=0;
            block_cen_n_delay<=0;
            z_new_pos_to_store_delay<=0;
            z_new_pos_to_store_delay1<=0;
            z_new_pos_to_store_delay2<=0;
            x_new_pos_to_store_delay<=0;
        end else begin
            effective_delay1<=effective;
            effective_delay2<=effective_delay1;
            effective_delay3<=effective_delay2;
            block_cen_n_delay<=block_cen_n;
            z_new_pos_to_store_delay<=z_new_pos_to_store;
            z_new_pos_to_store_delay1<=z_new_pos_to_store_delay;
            z_new_pos_to_store_delay2<=z_new_pos_to_store_delay1;
            x_new_pos_to_store_delay<=x_new_pos_to_store;
        end
    end
    logic [6-1:0] block_addr_first,block_addr_second;
    assign block_addr=effective_delay3 ? block_addr_first : 0;
    //(effective&&delta_addr)||(effective_delay1&&~delta_addr) 
    logic [DATA_WIDTH-1:0] mid1;
    multiple_simple_o m1(
        .clk(clk),
        .rst_n(rstn),
        .en(effective_delay1),
        .a(y_new_pos_to_store),
        .b(16'b11), // 8位的block数据
        .c(mid1)
    );
    add_simple_o a3(
        .clk(clk),
        .rst_n(rstn),
        .en(effective_delay2),
        .a(mid1),
        .b({11'b0,numx}),
        .c({rest,block_addr_first})
    );
    logic [4:0] restx,restx_pre,numx,step,partial_x_new_pos_to_store_delay;
    logic [10:0] rest_x_pos_delay;
    logic [6:0][8:0] data_out_all,data_out_all_store;
    logic [63:0] data_in_all;
    logic aa;
    assign {aa,data_out_all[6],data_out_all[5],data_out_all[4],data_out_all[3],data_out_all[2],data_out_all[1],data_out_all[0]}=block_data_out_pre;
    assign block_data_out=data_out_all[restx];
    always @(*) begin
        case(restx) 
            5'b00000: data_in_all={1'b0,data_out_all[6],data_out_all[5],data_out_all[4],data_out_all[3],data_out_all[2],data_out_all[1],block_data_in};
            5'b00001: data_in_all={1'b0,data_out_all[6],data_out_all[5],data_out_all[4],data_out_all[3],data_out_all[2],block_data_in,data_out_all[0]};
            5'b00010: data_in_all={1'b0,data_out_all[6],data_out_all[5],data_out_all[4],data_out_all[3],block_data_in,data_out_all[1],data_out_all[0]};
            5'b00011: data_in_all={1'b0,data_out_all[6],data_out_all[5],data_out_all[4],block_data_in,data_out_all[2],data_out_all[1],data_out_all[0]};
            5'b00100: data_in_all={1'b0,data_out_all[6],data_out_all[5],block_data_in,data_out_all[3],data_out_all[2],data_out_all[1],data_out_all[0]};
            5'b00101: data_in_all={1'b0,data_out_all[6],block_data_in,data_out_all[4],data_out_all[3],data_out_all[2],data_out_all[1],data_out_all[0]};
            5'b00110: data_in_all={1'b0,block_data_in,data_out_all[5],data_out_all[4],data_out_all[3],data_out_all[2],data_out_all[1],data_out_all[0]};
            default: data_in_all=64'b0;
        endcase
    end
    assign block_data_in_pre=data_in_all;
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
        end else begin
            restx<=restx_pre;
        end
    end

    logic [9-1:0] block_data_out_new;
    logic [8:0] block_data_in,block_data_out;
    assign block_data_out_new=(!block_cen_n_delay) ? block_data_out : 0;
    assign block_cen_n=(state!=2'b10)||(!(effective_delay3));
    assign block_wen=(~delta_addr);
    //&&(should_new);
    logic should_new;
    assign should_new=(block_data_out_new[9-2:0]>z_new_pos_to_store_delay2)||(block_data_out_new[9-1]==0);
    assign block_data_in={1'b1,((should_new) ? z_new_pos_to_store_delay2 : block_data_out_new[9-2:0])};


endmodule
module multiple_simple_o(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [16-1:0] a,
    input logic [16-1:0] b,
    output logic [16-1:0] c
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

module add_simple_o(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [16-1:0] a,
    input logic [16-1:0] b,
    output logic [16-1:0] c
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

module multiple_o #(
    parameter DATA_WIDTH=16
)(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [16-1:0] a,
    input logic [16-1:0] b,
    output logic [16-1:0] c
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

module divide_o #(
    parameter DATA_WIDTH=16
)(
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

module lut_block_addr_o   #(
    parameter DATA_WIDTH=16
)(
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
module add_o #(
    parameter data_width=16
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



module compute_new_pos_o  #(
    parameter DATA_WIDTH=16,
    parameter paraxy=16'b1010000000000, // 16位的paraxy
parameter sub_paraxy=16'b10100000000, // 16位的paraxy
parameter subparaxy_int=16'b10100
)(
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
    divide_o d1(clk, rst_n, en, x, z, xd);
    divide_o d2(clk, rst_n, en, y, z, yd);
    multiple_o m3(clk, rst_n, en, xd, pdfx, x_new_pos_pre1);
    multiple_o m4(clk, rst_n, en, yd, pdfy, y_new_pos_pre1);
    add_o a1(clk, rst_n, en, x_new_pos_pre1, paraxy, x_new_pos_pre2);
    add_o a2(clk, rst_n, en, y_new_pos_pre1, paraxy, y_new_pos_pre2);

    divide_o d3(clk, rst_n, en, z2, zblock, z_new_pos_pre2);
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
    in_frustrum_judge_o in_frustrum_judge_inst(
        .x_idx(x_idx),
        .y_idx(y_idx),
        .x(x_new_pos_pre2),
        .y(y_new_pos_pre2),
        .z(z_new_pos_pre2),
        .in(effective)
    );
    floor_o f1(
        .a(x_new_pos_pre2),
        .b(x_new_pos)
    );
    floor_o f2(
        .a(y_new_pos_pre2),
        .b(y_new_pos)
    ); 
    floor_o f3(
        .a(z_new_pos_pre2),
        .b(z_new_pos)
    );
endmodule

module in_frustrum_judge_o  #(
    parameter DATA_WIDTH=16,
    parameter paraxy=16'b1010000000000, // 16位的paraxy
parameter sub_paraxy=16'b10100000000, // 16位的paraxy
parameter subparaxy_int=16'b10100
)(
    input logic [2:0] x_idx,
    input logic [2:0] y_idx,
    input logic [DATA_WIDTH-1:0] x,
    input logic [DATA_WIDTH-1:0] y,
    input logic [DATA_WIDTH-1:0] z,
    output logic in
);
    logic p1,p2,p3,p4,p5,p6;
    bigger_o #(
        .width(DATA_WIDTH)
    ) x_bigger (
        .a(x),
        .b({13'b0,x_idx}*sub_paraxy),
        .c(p1)
    );
    bigger_o #(
        .width(DATA_WIDTH)
    ) x0_bigger (
        .a(x),
        .b({13'b0,x_idx+1'b1}*sub_paraxy),
        .c(p2)
    );
    bigger_o #(
        .width(DATA_WIDTH)
    ) y_bigger (
        .a(y),
        .b({13'b0,y_idx}*sub_paraxy),
        .c(p3)
    );
    bigger_o #(
        .width(DATA_WIDTH)
    ) y0_bigger (
        .a(y),
        .b({13'b0,x_idx+1'b1}*sub_paraxy),
        .c(p4)
    );
    
    bigger_o #(
        .width(DATA_WIDTH)
    ) z_bigger (
        .a(z),
        .b(0),
        .c(p5)
    );
    bigger_o #(
        .width(DATA_WIDTH)
    ) z0_bigger (
        .a(z),
        .b(paraxy),
        .c(p6)
    );
    assign in = p1&&(~p2) && p3 && (~p4) && p5 && (~p6);
    
endmodule

module bigger_o #(
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

module floor_o  #(
    parameter DATA_WIDTH=16
)(
    input logic [DATA_WIDTH-1:0] a,
    output logic [DATA_WIDTH-1:0] b
);
    assign b={a[DATA_WIDTH-1:6], 6'b0}; 
endmodule


module fp_to_int_o #(
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

module viewmetrics_fp_int_o  #(
    parameter DATA_WIDTH=16
)(
    input logic clk,
    input logic rstn,
    input logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics,
    output logic [3:0][3:0][DATA_WIDTH-1:0] viewmetrics_int
);
    genvar i, j;
    generate
        for (i = 0; i < 4; i = i + 1) begin : row
            for (j = 0; j < 4; j = j + 1) begin : col
                fp_to_int_o #(
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

module view_trans_o  #(
    parameter DATA_WIDTH=16
)(
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
    multiple_o m1(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[0][0]),
        .b(x),
        .c(mulx1)
    );
    multiple_o m2(
        .clk(clk),
        .rst_n(rstn),   
        .en(1),
        .a(viewmetrics[0][1]),
        .b(y),
        .c(muly1)
    );
    multiple_o m3(
        .clk(clk),
        .rst_n(rstn),
        .en(1),  
        .a(viewmetrics[0][2]),
        .b(z), 
        .c(mulz1)
    );
    multiple_o m4(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[0][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(mulx2)
    );
    multiple_o m5(
        .clk(clk), 
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[1][0]),  
        .b(x),
        .c(muly2)   
    );
    multiple_o m6(
        .clk(clk),
        .rst_n(rstn),
        .en(1), 
        .a(viewmetrics[1][1]),
        .b(y),
        .c(mulz2)
    );
    multiple_o m7(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[1][2]),    
        .b(z),
        .c(mulx3)
    );
    multiple_o m8(
        .clk(clk),      
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[1][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(muly3)
    );
    multiple_o m9(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[2][0]),  
        .b(x),
        .c(mulz3)
    );
    multiple_o m10(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[2][1]),
        .b(y),  
        .c(mulx4)
    );
    multiple_o m11(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[2][2]),
        .b(z),
        .c(muly4)
    );
    multiple_o m12(
        .clk(clk),  
        .rst_n(rstn),
        .en(1),
        .a(viewmetrics[2][3]),
        .b(16'h40), // 假设视锥体的w分量为1
        .c(mulz4)
    );
    add_o a1(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(mulx1),
        .b(mulx2),
        .c(addx1)
    );
    add_o a2(
        .clk(clk),
        .rst_n(rstn),   
        .en(1),
        .a(muly1),
        .b(muly2),  
        .c(addy1)
    );
    add_o a3(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(mulz1),
        .b(mulz2),
        .c(addz1)
    );
    add_o a4(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(mulx3),
        .b(mulx4),  
        .c(addx2)
    );
    add_o a5(
        .clk(clk),
        .rst_n(rstn),       
        .en(1),
        .a(muly3),
        .b(muly4),
        .c(addy2)
    );
    add_o a6(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(mulz3),
        .b(mulz4),  
        .c(addz2)
    );
     add_o a7(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(addx1),
        .b(addx2),
        .c(xo)
    );
    add_o a8(
        .clk(clk),  
        .rst_n(rstn),
        .en(1),
        .a(addy1),
        .b(addy2),
        .c(yo)
    );
    add_o a9(
        .clk(clk),
        .rst_n(rstn),
        .en(1),
        .a(addz1),
        .b(addz2),
        .c(zo)
    );
endmodule

module lut_tan_o  #(
    parameter DATA_WIDTH=16
)(
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