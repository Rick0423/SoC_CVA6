`timescale 1ns / 1ps
module get0 #(
    parameter DATA_WIDTH=16,
    parameter ANCHOR_DATA_WIDTH = 64,  // 3*fp16 (每个anchor 16位x3)
    parameter ANCHOR_LEVEL_DATA_WIDTH = 48,  // 3*fp16 (每个anchor 16位x3)
    parameter ANCHOR_ADDR_WIDTH = 7,  // 支持1024 anchor
    parameter ANCHOR_DEPTH      = 1024
)( 
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [16-1:0] distance_thresold,
    input logic [16-1:0] num_thresold,
    input logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start,
    input logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_end,

    // 与外部交互的sram_anchor数据访问接口
    output logic                         anchor_cen_n,
    output logic                         anchor_wen,
    output logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_final,
    input logic [ANCHOR_DATA_WIDTH-1:0] anchor_data_out,
    

    // 与外部交互的sram_anchor_level0数据访问接口
    output logic                         anchor_level0_cen_n,
    output logic                         anchor_level0_wen,
    output logic [4-1:0] anchor_level0_addr_final,
    output logic [ANCHOR_LEVEL_DATA_WIDTH-1:0] anchor_level0_data_in,
    output logic [31:0] total_effective_anchor_out,
    output logic done
);
    logic [2:0] state,next_state,get_other_or_done;
    logic get_first,get_other,total_done;
    logic self_rstn;
    logic rstn;
    logic [DATA_WIDTH-1:0] num_thresold_int,distance_thresold_int,num_thresold_store,distance_thresold_store;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_start_delay,anchor_addr_end_delay,anchor_addr_start_stored,anchor_addr_end_stored;
    logic start_delay;
    logic [1:0] state_first_count;
    logic [ANCHOR_ADDR_WIDTH-1:0] anchor_addr_first,anchor_addr_second;
    logic is_first;
    logic [DATA_WIDTH-1:0] xpos,ypos,zpos,level,xpos_store,ypos_store,zpos_store,level_store,xpos_fp,ypos_fp,zpos_fp;
    logic [DATA_WIDTH-1:0] xpos_int,ypos_int,zpos_int;
    logic get_other_pre;
    logic [3:0] get_other_count;
    logic [DATA_WIDTH-1:0] dx,dy,dz,dx2,dy2,dz2,dz2_delay,s2_2,s2;
    logic in_thresold;
    logic [15:0] s3_count,accum_count,accum_count_delay;
    logic [3:0] s4_count;
    logic [31:0] total_effective_anchor;
    logic state_is_011;
    assign rstn=rst_n&&(~total_done);
    assign anchor_wen=0;
    assign anchor_cen_n=0;
    always @(posedge clk) begin
        if (~rstn) begin
            state<=0;
        end else begin
            state<=next_state;
        end      
    end
  
    always @(*) begin
        case (state)
            3'b000: next_state=start ? 3'b001 : 3'b000;
            3'b001: next_state=3'b010;
            3'b010: next_state=get_first ? 3'b011 : 3'b010;
            3'b011: next_state=(get_other) ? 3'b100 : 3'b011;
            3'b100: next_state=(s4_count==1) ? 3'b101 : 3'b100;
            3'b101: next_state=total_done ? 3'b000: 3'b010;
            default: next_state=3'b000;
        endcase
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            start_delay<=0;
            anchor_addr_start_delay<=0;
            anchor_addr_end_delay<=0;
        end else begin
            start_delay<=start;
            anchor_addr_start_delay<=anchor_addr_start;
            anchor_addr_end_delay<=anchor_addr_end;
        end
    end
    
    fp_to_int #(
        .DATA_WIDTH(16)
    ) dis_thresold_fp_to_int (
        .clk(clk),
        .rstn(rstn),
        .a(distance_thresold),
        .c(distance_thresold_int)
    );

    always @(posedge clk) begin
        if (~rstn) begin
            num_thresold_store<=0;
            distance_thresold_store<=0;
            anchor_addr_start_stored<=0;
            anchor_addr_end_stored<=0;
        end else if (start_delay) begin
            distance_thresold_store<=distance_thresold_int;
            anchor_addr_start_stored<=anchor_addr_start_delay;
            anchor_addr_end_stored<=anchor_addr_end_delay;
        end else if (start) begin
            num_thresold_store<=num_thresold;
        end
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            state_first_count<=0;
        end else if (state==3'b010) begin
            state_first_count<=state_first_count+1;
        end else begin
            state_first_count<=0;
        end
    end
    assign get_first=(state_first_count==2'b11);
   
    always @(posedge clk) begin
        if (~rstn) begin
            anchor_addr_first<=0;
            anchor_addr_second<=0;
            is_first<=0;
        end else if (state==3'b010&&(~is_first)&&state_first_count==0) begin
            is_first<=1;
            anchor_addr_first<=anchor_addr_start_stored;
            anchor_addr_second<=anchor_addr_start_stored;
        end else if (state==3'b010&&state_first_count==3) begin
            anchor_addr_first<=anchor_addr_first+10;
        end else if (state==3'b011) begin
            anchor_addr_second<=anchor_addr_second+10;
        end else if (state==3'b100) begin
            anchor_addr_second<=anchor_addr_start_stored;
        end
    end
    assign anchor_addr_final=(state==3'b010) ? anchor_addr_first : anchor_addr_second;
    
    assign {xpos,ypos,zpos,level}=anchor_data_out;
    fp_to_int #(
        .DATA_WIDTH(DATA_WIDTH)
    ) xpos_fp_to_int (
        .clk(clk),
        .rstn(rstn),
        .a(xpos),
        .c(xpos_int)
    );
    fp_to_int #(
        .DATA_WIDTH(DATA_WIDTH)
    ) ypos_fp_to_int (
        .clk(clk),
        .rstn(rstn),
        .a(ypos),
        .c(ypos_int)
    );
    fp_to_int #(
        .DATA_WIDTH(DATA_WIDTH)
    ) zpos_fp_to_int (
        .clk(clk),
        .rstn(rstn),
        .a(zpos),
        .c(zpos_int)
    );
    always @(posedge clk) begin
        if (~rstn) begin
            xpos_store<=0;
            ypos_store<=0;
            zpos_store<=0;
            xpos_fp<=0;
            ypos_fp<=0;
            zpos_fp<=0;
            level_store<=0;
        end else if (state==3'b010) begin
            xpos_store<=xpos_int;
            ypos_store<=ypos_int;
            zpos_store<=zpos_int;
            xpos_fp<=xpos;
            ypos_fp<=ypos;
            zpos_fp<=zpos;
            level_store<=level;
        end
    end
    
    assign get_other_pre=(anchor_addr_second>anchor_addr_end_stored);
    
    always @(posedge clk) begin
        if (~rstn) begin
            get_other_count<=0;
        end else if (get_other_pre) begin
            get_other_count<=get_other_count+1;
        end else begin
            get_other_count<=0;
        end
    end
    assign get_other=(get_other_count==5);
    
    always @(posedge clk) begin
        if (~rstn) begin
            dz2_delay<=0;
        end else begin
            dz2_delay<=dz2;
        end
    end
    assign state_is_011=(state==3'b011);
    add #(
        .data_width(DATA_WIDTH)
    ) add_dx (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(xpos_store),
        .b({~xpos_int[DATA_WIDTH-1],xpos_int[DATA_WIDTH-2:0]}), // 计算 dx = xpos_store - xpos_int
        .c(dx)
    );
    add #(
        .data_width(DATA_WIDTH)
    ) add_dy (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(ypos_store),
        .b({~ypos_int[DATA_WIDTH-1],ypos_int[DATA_WIDTH-2:0]}), // 计算 dy = ypos_store - ypos_int
        .c(dy)
    );
    add #(
        .data_width(DATA_WIDTH)
    ) add_dz (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(zpos_store),
        .b({~zpos_int[DATA_WIDTH-1],zpos_int[DATA_WIDTH-2:0]}), // 计算 dz = zpos_store - zpos_int
        .c(dz)
    );
    
    multiple multiple_dx (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(dx),
        .b(dx),
        .c(dx2) // 计算 dx^2
    );
    multiple multiple_dy (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(dy),
        .b(dy),
        .c(dy2) // 计算 dy^2
    );
    multiple multiple_dz (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(dz),
        .b(dz),
        .c(dz2) // 计算 dz^2
    );
    add #(
        .data_width(DATA_WIDTH)
    ) add_s2 (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(dx2),
        .b(dy2),
        .c(s2_2) // 计算 s2 = dx^2 + dy^2
    );
    
    add #(
        .data_width(DATA_WIDTH)
    ) add_s2_dz (
        .clk(clk),
        .rst_n(rstn),
        .en(state_is_011),
        .a(s2_2),
        .b(dz2_delay),
        .c(s2) // 计算 s2 = dx^2 + dy^2
    );
    
    bigger #(
        .width(DATA_WIDTH)
    ) bigger_s2 (
        .a(distance_thresold_store),
        .b(s2),
        .c(in_thresold) // 如果 s2 > distance_thresold_store，则 get_other 为 1
    );
    
    always @(posedge clk) begin
        if (~rstn) begin
            s3_count<=0;
        end else if (state==3'b011) begin
            s3_count<=s3_count+1;
        end else begin
            s3_count<=0;
        end
    end
    always @(posedge clk) begin
        if (~rstn) begin
            accum_count<=0;
        end else if ((state==3'b011)&&(s3_count>=6)) begin
            accum_count<=accum_count+{15'b0,in_thresold};
        end else begin
            accum_count<=0;
        end
    end
    always @(posedge clk) begin
        if (~rstn) begin
            accum_count_delay<=0;
        end else begin
            accum_count_delay<=accum_count;
        end
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            s4_count<=0;
        end else if (state==3'b100) begin
            s4_count<=s4_count+1;
        end else begin
            s4_count<=0;
        end
    end
    
    always @(posedge clk) begin
        if (~rstn) begin
            anchor_level0_addr_final<=0;
        end else if (~anchor_level0_cen_n)begin
            anchor_level0_addr_final<=anchor_level0_addr_final+1;
        end
    end
    assign anchor_level0_cen_n=~((accum_count_delay>=num_thresold_store)&&(s4_count==1)&&(level_store==0));
    assign anchor_level0_wen=~anchor_level0_cen_n;
    assign anchor_level0_data_in={xpos_fp,ypos_fp,zpos_fp};
    assign total_done=anchor_addr_first>anchor_addr_end_stored+10;
    assign done=total_done;
    
    always @(posedge clk) begin
        if (~rstn) begin
            total_effective_anchor<=0;
        end else if ((anchor_level0_wen!=0)&&(total_done==0)) begin
            total_effective_anchor<=total_effective_anchor+1;
        end else begin
            total_effective_anchor<=total_effective_anchor;
        end
    end
    assign total_effective_anchor_out = (total_done) ? total_effective_anchor :0;
endmodule

module fp_to_int #(
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

module bigger #(
    parameter width
)(
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    output logic c
);
    logic d;
    assign d=a>b;
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

module add #(
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

module multiple #(
    parameter DATA_WIDTH=16
)(
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

