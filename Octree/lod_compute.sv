
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/27 01:33:51
// Design Name: 
// Module Name: lod_compute
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module fp16_minus(
    input  logic                        clk                        ,
    input  logic         [  15: 0]      floatA                     ,
    input  logic         [  15: 0]      floatB                     ,
    output logic         [  15: 0]      minus_out                  );

    logic                               sign                        ;
    logic   signed       [   5: 0]      exponent                    ;// fifth bit is sign
    logic                [   9: 0]      mantissa                    ;
    logic                [   4: 0]      exponentA,                exponentB;
    logic                [  10: 0]      fractionA,                fractionB,fraction;// fraction = {1, mantissa}
    logic                [   4: 0]      shiftAmount                 ;
    logic                               cout                        ;
    logic                [  15: 0]      floatB_minus                ;
    always @(posedge clk) begin
    floatB_minus={~floatB[15],floatB[14:0]};
    // 提取指数和尾数
    exponentA = floatA[14:10];
    exponentB = floatB_minus[14:10];
    fractionA = {1'b1, floatA[9:0]};                                // 将隐藏位表示出来进行计算
    fractionB = {1'b1, floatB_minus[9:0]};                          // 同理

    exponent = {1'b0,exponentA};

    // 特殊情况处理
    if (floatA == 0) begin                                          // floatA = 0
        minus_out=  floatB_minus;
    end else if (floatB_minus == 0) begin                           // floatB = 0
        minus_out= floatA;
    end else if (floatA[14:0] == floatB_minus[14:0] && floatA[15] ^ floatB_minus[15] == 1'b1) begin
        minus_out= 16'b0;                                           // 相同绝对值但符号不同
    end else begin
        // 对阶
        if (exponentB > exponentA) begin
            shiftAmount = exponentB - exponentA;
            fractionA = fractionA >> shiftAmount;                   // 尾数右移
            exponent = {1'b0,exponentB};
        end else if (exponentA > exponentB) begin
            shiftAmount = exponentA - exponentB;
            fractionB = fractionB >> shiftAmount;
            exponent = {1'b0,exponentA};
        end

        // 同符号相加
        if (floatA[15] == floatB_minus[15]) begin
            {cout, fraction} = fractionA + fractionB;
            if (cout == 1'b1) begin
                {cout, fraction} = {cout, fraction} >> 1;           // 归一化
                exponent = exponent + 1;
            end
            sign = floatA[15];
        end else begin                                              // 不同符号
            if (floatA[15] == 1'b1) begin
                {cout, fraction} = fractionB - fractionA;           // B - A
            end else begin
                {cout, fraction} = fractionA - fractionB;           // A - B
            end
            sign = cout;
            if (cout == 1'b1) begin
                fraction = -fraction;                               // 转换为原码
            end
        end

        // 规格化
        if (fraction[10] == 0) begin
            if (fraction[9] == 1'b1) begin
                fraction = fraction << 1;
                exponent = exponent - 1;
            end else if (fraction[8] == 1'b1) begin
                fraction = fraction << 2;
                exponent = exponent - 2;
            end else if (fraction[7] == 1'b1) begin
                fraction = fraction << 3;
                exponent = exponent - 3;
            end else if (fraction[6] == 1'b1) begin
                fraction = fraction << 4;
                exponent = exponent - 4;
            end else if (fraction[5] == 1'b1) begin
                fraction = fraction << 5;
                exponent = exponent - 5;
            end else if (fraction[4] == 1'b1) begin
                fraction = fraction << 6;
                exponent = exponent - 6;
            end else if (fraction[3] == 1'b1) begin
                fraction = fraction << 7;
                exponent = exponent - 7;
            end else if (fraction[2] == 1'b1) begin
                fraction = fraction << 8;
                exponent = exponent - 8;
            end else if (fraction[1] == 1'b1) begin
                fraction = fraction << 9;
                exponent = exponent - 9;
            end else if (fraction[0] == 1'b1) begin
                fraction = fraction << 10;
                exponent = exponent - 10;
            end
        end

        mantissa = fraction[9:0];
        if (exponent == 6'b000001) begin                            // 指数溢出处理
            minus_out= 16'b0000000000000000;                        // 返回零
        end else begin
            minus_out= {sign, exponent[4:0], mantissa};             // 返回结果
        end
    end
    end
endmodule
module fp16_add(
    input  logic                        clk                        ,
    input  logic         [  15: 0]      floatA                     ,
    input  logic         [  15: 0]      floatB                     ,
    output logic         [  15: 0]      add_out                    );
    logic                               sign                        ;
    logic   signed       [   5: 0]      exponent                    ;// fifth bit is sign
    logic                [   9: 0]      mantissa                    ;
    logic                [   4: 0]      exponentA,                exponentB;
    logic                [  10: 0]      fractionA,                fractionB,fraction;// fraction = {1, mantissa}
    logic                [   4: 0]      shiftAmount                 ;
    logic                               cout                        ;
    ;
    always @(posedge clk) begin
    
    // 提取指数和尾数
    exponentA = floatA[14:10];
    exponentB = floatB[14:10];
    fractionA = {1'b1, floatA[9:0]};                                // 将隐藏位表示出来进行计算
    fractionB = {1'b1, floatB[9:0]};                                // 同理

    exponent = {1'b0,exponentA};

    // 特殊情况处理
    if (floatA == 0) begin                                          // floatA = 0
        add_out=  floatB;
    end else if (floatB == 0) begin                                 // floatB = 0
        add_out= floatA;
    end else if (floatA[14:0] == floatB[14:0] && floatA[15] ^ floatB[15] == 1'b1) begin
        add_out= 16'b0;                                             // 相同绝对值但符号不同
    end else begin
        // 对阶
        if (exponentB > exponentA) begin
            shiftAmount = exponentB - exponentA;
            fractionA = fractionA >> shiftAmount;                   // 尾数右移
            exponent = {1'b0,exponentB};
        end else if (exponentA > exponentB) begin
            shiftAmount = exponentA - exponentB;
            fractionB = fractionB >> shiftAmount;
            exponent = {1'b0,exponentA};
        end

        // 同符号相加
        if (floatA[15] == floatB[15]) begin
            {cout, fraction} = fractionA + fractionB;
            if (cout == 1'b1) begin
                {cout, fraction} = {cout, fraction} >> 1;           // 归一化
                exponent = exponent + 1;
            end
            sign = floatA[15];
        end else begin                                              // 不同符号
            if (floatA[15] == 1'b1) begin
                {cout, fraction} = fractionB - fractionA;           // B - A
            end else begin
                {cout, fraction} = fractionA - fractionB;           // A - B
            end
            sign = cout;
            if (cout == 1'b1) begin
                fraction = -fraction;                               // 转换为原码
            end
        end

        // 规格化
        if (fraction[10] == 0) begin
            if (fraction[9] == 1'b1) begin
                fraction = fraction << 1;
                exponent = exponent - 1;
            end else if (fraction[8] == 1'b1) begin
                fraction = fraction << 2;
                exponent = exponent - 2;
            end else if (fraction[7] == 1'b1) begin
                fraction = fraction << 3;
                exponent = exponent - 3;
            end else if (fraction[6] == 1'b1) begin
                fraction = fraction << 4;
                exponent = exponent - 4;
            end else if (fraction[5] == 1'b1) begin
                fraction = fraction << 5;
                exponent = exponent - 5;
            end else if (fraction[4] == 1'b1) begin
                fraction = fraction << 6;
                exponent = exponent - 6;
            end else if (fraction[3] == 1'b1) begin
                fraction = fraction << 7;
                exponent = exponent - 7;
            end else if (fraction[2] == 1'b1) begin
                fraction = fraction << 8;
                exponent = exponent - 8;
            end else if (fraction[1] == 1'b1) begin
                fraction = fraction << 9;
                exponent = exponent - 9;
            end else if (fraction[0] == 1'b1) begin
                fraction = fraction << 10;
                exponent = exponent - 10;
            end
        end

        mantissa = fraction[9:0];
        if (exponent == 6'b000001) begin                            // 指数溢出处理
            add_out= 16'b0000000000000000;                          // 返回零
        end else begin
            add_out= {sign, exponent[4:0], mantissa};               // 返回结果
        end
    end
    end
endmodule



module fp16_mult(
    input  logic                        clk                        ,
    input  logic         [  15: 0]      floatA                     ,
    input  logic         [  15: 0]      floatB                     ,
    output logic         [  15: 0]      mult_out                   );
    logic                               sign                        ;
    logic   signed       [   5: 0]      exponent                    ;// 6th bit is the sign
    logic                [   9: 0]      mantissa                    ;
    logic                [  10: 0]      fractionA,                fractionB;// fraction = {1, mantissa}
    logic                [  21: 0]      fraction                    ;
    always @(posedge clk) begin
    // 特殊情况处理
    if (floatA == 0 || floatB == 0) begin
        mult_out= 16'b0;                                            // 乘以零的情况
    end else begin
        sign = floatA[15] ^ floatB[15];                             // 异或，相异为1
        exponent = floatA[14:10] + floatB[14:10] - 5'd15;

        // 显示出隐藏位1来计算
        fractionA = {1'b1, floatA[9:0]};
        fractionB = {1'b1, floatB[9:0]};
        fraction = fractionA * fractionB;

        // 规格化过程
        if (fraction[21] == 1'b1) begin                             // 规格化，将隐藏位再次隐藏起来
            fraction = fraction << 1;
            exponent = exponent + 1;
        end else if (fraction[20] == 1'b1) begin
            fraction = fraction << 2;
            exponent = exponent + 0;
        end else if (fraction[19] == 1'b1) begin
            fraction = fraction << 3;
            exponent = exponent - 1;
        end else if (fraction[18] == 1'b1) begin
            fraction = fraction << 4;
            exponent = exponent - 2;
        end else if (fraction[17] == 1'b1) begin
            fraction = fraction << 5;
            exponent = exponent - 3;
        end else if (fraction[16] == 1'b1) begin
            fraction = fraction << 6;
            exponent = exponent - 4;
        end else if (fraction[15] == 1'b1) begin
            fraction = fraction << 7;
            exponent = exponent - 5;
        end else if (fraction[14] == 1'b1) begin
            fraction = fraction << 8;
            exponent = exponent - 6;
        end else if (fraction[13] == 1'b1) begin
            fraction = fraction << 9;
            exponent = exponent - 7;
        end else if (fraction[12] == 1'b0) begin
            fraction = fraction << 10;
            exponent = exponent - 8;
        end

        mantissa = fraction[21:12];

        // 指数溢出处理
        if (exponent == 6'b000001) begin                            // exponent is negative
            mult_out=16'b0000000000000000;                          // 返回零
        end else begin
            mult_out={sign, exponent[4:0], mantissa};               // 返回结果
        end
    end
    end
endmodule




module fp16_log2(
    input  logic                        clk                        ,
    input  logic         [  15: 0]      fpin                       ,
    output logic         [  15: 0]      result                     );
    logic                [  15: 0]      result_int                  ;
    
    logic                [  15: 0]      result_fp                   ;
    logic                [   9: 0]      fpin_fp                     ;
    logic                [   4: 0]      mid                         ;
    logic                [  15: 0]      result_fp_sub,            result_sub;
    logic                [  15: 0]      result_pre                  ;
    
    always @(posedge clk) begin
    mid=fpin[14:10]-5'd15;
    //result_int ={1'b0, mid, 10'b0};
    fpin_fp=fpin[9:0];
    
    case(fpin_fp) inside
        [0:22]: result_fp<=16'b0011110000000000;
        [23:69]: result_fp<=16'b0011110001000000;
        [70:117]: result_fp<=16'b0011110010000000;
        [118:168]: result_fp<=16'b0011110011000000;
        [169:220]: result_fp<=16'b0011110100000000;
        [221:275]: result_fp<=16'b0011110101000000;
        [276:333]: result_fp<=16'b0011110110000000;
        [334:393]: result_fp<=16'b0011110111000000;
        [394:456]: result_fp<=16'b0011111000000000;
        [457:521]: result_fp<=16'b0011111001000000;
        [522:590]: result_fp<=16'b0011111010000000;
        [591:662]: result_fp<=16'b0011111011000000;
        [663:736]: result_fp<=16'b0011111100000000;
        [737:814]: result_fp<=16'b0011111101000000;
        [815:896]: result_fp<=16'b0011111110000000;
        default: result_fp<=16'b0011111111000000;
    endcase
    case (mid)
    0:result_int<=16'b0000000000000000;
    1:result_int<=16'b0011110000000000;
    2:result_int<=16'b0100000000000000;
    3:result_int<=16'b0100001000000000;
    4:result_int<=16'b0100010000000000;
    5:result_int<=16'b0100010100000000;
    6:result_int<=16'b0100011000000000;
    7:result_int<=16'b0100011100000000;
    8:result_int<=16'b0100100000000000;
    9:result_int<=16'b0100100010000000;
    10:result_int<=16'b0100100100000000;
    11:result_int<=16'b0100100110000000;
    12:result_int<=16'b0100101000000000;
    13:result_int<=16'b0100101010000000;
    14:result_int<=16'b0100101100000000;
    15:result_int<=16'b0100101110000000;
    16:result_int<=16'b0100110000000000;
    endcase
    
    
    end
    fp16_minus fp1(clk, result_fp,16'b0011110000000000, result_fp_sub);
    fp16_add fp2(clk, result_int, result_fp_sub, result_pre);
    
    assign      result               = (fpin[15]) ? 16'b0111110000000001 : result_pre;
    
endmodule

module lod_compute #(
    parameter       LOD_START_ADDR              = 0     ,
    parameter       TREE_LEVEL                  = 4     
)(
    input  logic         [  15: 0]      s                          ,
    input  logic         [  15: 0]      dist_max                   ,
    input  logic                        clk                        ,
    input  logic                        rst_n                      ,
    input  logic                        cal_lod                    ,//是否需要进行计算，如果需要为高，否则为低.模块使能
    output logic                        lod_ready                  ,
 
    output logic                        mem_sram_CEN               ,// 芯片使能，低有效
    output logic         [  63: 0]      mem_sram_A                 ,// 地址
    output logic         [  63: 0]      mem_sram_D                 ,// 写入数据
    output logic                        mem_sram_GWEN              ,// 读写使能：0 写，1 读
    input  logic         [  63: 0]      mem_sram_Q                 ,// 读出数据
    //在SRAM中保存有这个Octree的position和每一层的delta L信息（一整个Octree的所有anchor共用同一个position，在同一个level的所有anchor共用一个delta L）
    //在SRAM中的数据按照这个格式存储：以64个为一组，每一个octree保存3个64.
    // 1、  ｜16 (x)        | 16 (y)    | 16 (z)    | 16(layer 1 delta L)| 
    // 2、  | 16(layer 2)   |(layer 3)  | (layer 4) |(layer5)           |
    // 3、  | 16(layer 6)   |(layer 7)  | (layer 8) |(empty)            |
    //SRAM接口，直接操作读写即可，读写地址为    LOD_START_ADDR+3*current_tree_count 例如当current_tree_count为0 的时候需要读的地址就是LOD_START_ADDR，current_tree_count为5的时候，需要读的地址就是LOD_START_ADDR+3*5
    input  logic         [2:0][15: 0]      cam_pos                    ,
    input  logic            [  15: 0]      current_tree_count         ,//表示当前正在处理的是那一颗Octree，用于确定mem中的地址
    output logic    [TREE_LEVEL-1: 0]      lod_active                  //最后的结果输出，表示第i位是否要输出，例如：
    //1-1-0-0-0-0-0-0   表示level 0 和 1的有效，其余均无效； 1-1-1-1-0-0-0-0     表示 level 0-3有效；
    //1-0-0-1-0-0-0-0   表示level 0 和 3的anchor有效，其余均无效（理论上，在delta L巨大的场景下有可能出现）
);
    
    //需要完成的是
    //1、根据提供的公式计算每一层的int_layer,
    //2、然后判断当前层要不要在之后输出，如果需要输出那就将lod_active的对应的置为1，否则为0,同时将lod_ready置高
    //计算中使用到的数据是cam_pos，cam_pos[0]、cam_pos[1]、cam_pos[2]分别代表x、y、z的坐标，每一个坐标都是fp16的数。
    //计算中针对一个octree只计算一次，默认这个octree中
    assign      mem_sram_GWEN        = 1;
    //assign mem_sram_CEN  = (cal_lod)?0:1;
    reg                  [   4: 0]      lod_active_temp             ;
    reg                  [3:0][15: 0]      oct_pos                     ;
    reg                  [4:0][15: 0]      oct_lay_dL                  ;
    reg                  [  15: 0]      dist_pow_x,dist_pow_y,dist_pow_z,log_dist_max_pow2  ;
    reg                  [  15: 0]      i_to_fp16_cut,int_layer_1,int_layer_2,int_layer_3,int_layer_4,int_layer_5,int_layer_6,int_layer_7,int_layer_8  ;
    reg                  [  15: 0]      int_layer                   ;
    reg                  [  15: 0]      minus_1,minus_2,minus_3,minus_4,minus_5  ;
    typedef enum logic [3:0] {
        idle=4'b000,s0=4'b0001,s1=4'b0010,s2=4'b0011,s3=4'b0100,s4=4'b0101,s5=4'b0110,s6=4'b0111,s7=4'b1000,s8=4'b1001,s9=4'b1010,s10=4'b1011, s11=4'b1100,s12=4'b1101,s13=4'b1110
    } state_t;
    state_t state, next_state;
    
    logic                               te                          ;
    logic                [  15: 0]      fp22_temp,                fp11_temp,fp00_temp,dist_x_pow_temp,dist_y_pow_temp,dist_z_pow_temp;
    fp16_minus fp22_minus(clk, cam_pos[2],oct_pos[0],fp22_temp);
    fp16_mult fp22_mult(clk,fp22_temp,fp22_temp,dist_x_pow_temp);
    fp16_minus fp11_minus(clk, cam_pos[1],oct_pos[1],fp11_temp);
    fp16_mult fp11_mult(clk,fp11_temp,fp11_temp,dist_y_pow_temp);
    fp16_minus fp00_minus(clk, cam_pos[0],oct_pos[2],fp00_temp);
    fp16_mult fp00_mult(clk,fp00_temp,fp00_temp,dist_z_pow_temp);
    logic                [  15: 0]      total_dist_pow_temp1,     total_dist_pow_temp2;
    fp16_add total_dist_add(clk, dist_x_pow_temp, dist_y_pow_temp, total_dist_pow_temp1);
    fp16_add total_dist_add_1(clk, total_dist_pow_temp1, dist_z_pow_temp, total_dist_pow_temp2);
    logic                [  15: 0]      log_dist_max_temp,log_total_dist_pow_temp,log_s_temp  ;
    fp16_log2 fp_log_dist_max(clk, dist_max, log_dist_max_temp);
    fp16_log2 fp_log_total_dist(clk, total_dist_pow_temp2, log_total_dist_pow_temp);
    fp16_log2 fp_log_s(clk, s,log_s_temp);
    logic                [  15: 0]      log_total_dist_temp         ;
    fp16_mult fp_mult_log_total_dist(clk,log_total_dist_pow_temp,16'b0011100000000000,log_total_dist_temp);
    logic                [  15: 0]      pre_int_layer_temp1,      pre_int_layer_temp2;
    fp16_minus fp_minus_pre_int_temp1(clk, log_dist_max_temp, log_total_dist_temp, pre_int_layer_temp1);
    fp16_minus fp_minus_pre_int_temp2(clk, pre_int_layer_temp1, log_s_temp, pre_int_layer_temp2);
    logic                [  15: 0]      minus_1_temp1,            minus_1_temp2,minus_2_temp1,minus_2_temp2,minus_3_temp1,minus_3_temp2,minus_4_temp1,minus_4_temp2,minus_5_temp1,minus_5_temp2;
    fp16_add temp1_1(clk, pre_int_layer_temp2, oct_lay_dL[0], minus_1_temp1);
    fp16_minus temp1_2(clk, minus_1_temp1, 16'b0011110000000000, minus_1_temp2);
    fp16_add temp2_1(clk, pre_int_layer_temp2, oct_lay_dL[1], minus_2_temp1);
    fp16_minus temp2_2(clk, minus_2_temp1, 16'b0100000000000000, minus_2_temp2);
    fp16_add temp3_1(clk, pre_int_layer_temp2, oct_lay_dL[2], minus_3_temp1);
    fp16_minus temp3_2(clk, minus_3_temp1, 16'b0100001000000000, minus_3_temp2);
    fp16_add temp4_1(clk, pre_int_layer_temp2, oct_lay_dL[3], minus_4_temp1);
    fp16_minus temp4_2(clk, minus_4_temp1, 16'b0100010000000000, minus_4_temp2);
    fp16_add temp5_1(clk, pre_int_layer_temp2, oct_lay_dL[4], minus_5_temp1);
    fp16_minus temp5_2(clk, minus_5_temp1, 16'b0100010100000000, minus_5_temp2);
    logic                [  15: 0]      oct_temp=16'b0              ;
    logic                               oct_flag=1'b0               ;
    logic                [   4: 0]      lod_active_reg              ;
    logic                               lod_active_ready=1'b0       ;
    logic                               lod_active_ready_new=1'b0   ;
    always @(posedge clk)begin
        state<=next_state;
    end
    always @(*)begin
        oct_pos[2]=16'b0;
        oct_pos[1]=16'b0;
        oct_pos[0]=16'b0;
        oct_lay_dL[4]=16'b0;
        oct_lay_dL[3]=16'b0;
        oct_lay_dL[2]=16'b0;
        oct_lay_dL[1]=16'b0;
        oct_lay_dL[0]=16'b0;
        oct_temp=16'b0;
        oct_flag=1'b0;
        lod_active_ready=1'b0;
        lod_active_ready_new=1'b0;
        mem_sram_CEN =1'b1;
        case (state)
            idle: begin
                if (cal_lod==1) begin
                next_state= (rst_n) ? s0:idle;
                end
                else begin next_state=idle;
                end
                lod_ready=0;
                mem_sram_A=64'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                
                end
            s0: begin
                next_state = (rst_n) ? s1:idle;
                lod_ready=0;
                mem_sram_A =  LOD_START_ADDR+ current_tree_count * 2;
                mem_sram_CEN =1'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
               
                end
            s1: begin
                next_state =  (rst_n) ? s2:idle;
                mem_sram_A = LOD_START_ADDR+ current_tree_count * 2;
                mem_sram_CEN =1'b0;
                oct_pos[0] = mem_sram_Q[63:48];
                oct_pos[1] = mem_sram_Q[47:32];
                oct_pos[2] = mem_sram_Q[31:16];
                //oct_lay_dL[0] = mem_sram_Q[15:0];
                lod_ready=0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
                
                end
      
            s2: begin
                next_state =  (rst_n) ? s3:idle;
                //oct_lay_dL[1] = mem_sram_Q[63:48];
                //oct_lay_dL[2] = mem_sram_Q[47:32];
                //oct_lay_dL[3] = mem_sram_Q[31:16];
                //oct_lay_dL[4] = mem_sram_Q[15:0];
                lod_ready=0;
                mem_sram_A = 64'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
                oct_pos[0] = mem_sram_Q[63:48];
                oct_pos[1] = mem_sram_Q[47:32];
                oct_pos[2] = mem_sram_Q[31:16];
                end
            
            s3: begin
                next_state =  (rst_n) ? s4:idle;
                dist_pow_x=dist_x_pow_temp;
                dist_pow_y=dist_y_pow_temp;
                dist_pow_z=dist_z_pow_temp;
                lod_ready=0;
                mem_sram_A=64'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
               
                end
            s4: begin
                next_state= (rst_n) ? s5:idle;
                //total_dist_pow=total_dist_pow_temp2;
                lod_ready=0;
                mem_sram_A=LOD_START_ADDR+ current_tree_count * 2+1;
                mem_sram_CEN =1'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
                
                end
            s5: begin
                next_state=(rst_n) ? s6:idle;
                //log_dist_max=log_dist_max_temp;
                //log_total_dist_pow=log_total_dist_pow_temp;
                //log_s=log_s_temp;
                lod_ready=0;
                mem_sram_A=LOD_START_ADDR+ current_tree_count * 2+1;
                mem_sram_CEN =1'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
                oct_lay_dL[1] = mem_sram_Q[63:48];
                oct_lay_dL[2] = mem_sram_Q[47:32];
                oct_lay_dL[3] = mem_sram_Q[31:16];
                oct_lay_dL[4] = mem_sram_Q[15:0];
                end
            s6: begin
                next_state=(rst_n) ? s7:idle;
                //log_total_dist=log_total_dist_temp;
                lod_ready=0;
                mem_sram_A=LOD_START_ADDR+ current_tree_count * 2+1;
                mem_sram_CEN =1'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //mem_sram_A=64'b0;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
               oct_lay_dL[1] = mem_sram_Q[63:48];
                oct_lay_dL[2] = mem_sram_Q[47:32];
                oct_lay_dL[3] = mem_sram_Q[31:16];
                oct_lay_dL[4] = mem_sram_Q[15:0];
                end
            s7: begin
                next_state=(rst_n) ? s8:idle;
                //pre_int_layer=pre_int_layer_temp2;
                lod_ready=0;
                mem_sram_A=LOD_START_ADDR + current_tree_count * 2+1;
                mem_sram_CEN =1'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //mem_sram_A=64'b0;
                oct_lay_dL[1] = mem_sram_Q[63:48];
                oct_lay_dL[2] = mem_sram_Q[47:32];
                oct_lay_dL[3] = mem_sram_Q[31:16];
                oct_lay_dL[4] = mem_sram_Q[15:0];
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
            end
            s8: begin
                next_state=(rst_n) ? s9:idle;
                //pre_int_layer=pre_int_layer_temp2;
                lod_ready=0;
                mem_sram_A=64'b0;
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                //mem_sram_A=64'b0;
                oct_lay_dL[1] = mem_sram_Q[63:48];
                oct_lay_dL[2] = mem_sram_Q[47:32];
                oct_lay_dL[3] = mem_sram_Q[31:16];
                oct_lay_dL[4] = mem_sram_Q[15:0];
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                oct_flag=1'b1;
                end
            s9: begin
                next_state =  (rst_n) ? s10:idle;
               //lod_ready = 1;
                
                lod_active_ready=1'b1;
                //oct_lay_dL[0]=oct_temp;
                //oct_temp=oct_lay_dL[0];
                //minus_1=minus_1_temp2;
                //if (minus_1_temp2[15])
                //    lod_active_temp[TREE_LEVEL-1] = 0;
                //else
                //    lod_active_temp[TREE_LEVEL-1] = 1;
                
                //minus_2=minus_2_temp2;
                if (minus_2_temp2[15])
                    lod_active_temp[5-2] = 0;
                else
                     lod_active_temp[5-2] = 1;
                
                //minus_3=minus_3_temp2;
                if (minus_3_temp2[15])
                    lod_active_temp[5-3] = 0;
                 else
                     lod_active_temp[5-3] = 1;
                   
                //minus_4=minus_4_temp2;
                if (minus_4_temp2[15])
                    lod_active_temp[5-4] = 0;
                else
                     lod_active_temp[5-4] = 1;
                     
                //minus_5=minus_5_temp2;
                if (minus_5_temp2[15])
                    lod_active_temp[5-5] = 0;
                else
                     lod_active_temp[5-5] = 1;
                lod_active_temp[4]=1'b0;
                lod_ready=0;
                mem_sram_A=LOD_START_ADDR + current_tree_count * 2;
                //lod_active=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                oct_flag=1'b1;
                
                end
            s10:begin
            next_state =  (rst_n) ? s11:idle;
            lod_active_ready=1'b0;
            lod_ready=0;
            oct_lay_dL[0]=mem_sram_Q[15:0];
            mem_sram_A=LOD_START_ADDR + current_tree_count * 2;
            mem_sram_CEN =1'b0;
           
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
            end
            s11:begin
                next_state =  (rst_n) ? s12:idle;
            lod_active_ready=1'b0;
            lod_ready=0;
            oct_lay_dL[0]=mem_sram_Q[15:0];
            mem_sram_A=64'b0;
           
                //lod_active=5'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
            end
            s12:begin
            next_state =  (rst_n) ? s13:idle;
            lod_active_ready_new=1'b1;
            
            lod_ready=0;
            if (minus_1_temp2[15])
                 lod_active_temp[5-1] = 0;
             else
                  lod_active_temp[5-1] = 1;
            mem_sram_A=64'b0;
                //lod_active=5'b0;
                lod_active_temp[3]=1'b0;
                lod_active_temp[2]=1'b0;
                lod_active_temp[1]=1'b0;
                lod_active_temp[0]=1'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
            
            end
            s13: begin
                next_state=idle;
                lod_ready = 1;
                //lod_active=lod_active_temp;
                mem_sram_A=64'b0;
                lod_active_temp=5'b0;
                dist_pow_x=16'b0;
                dist_pow_y=16'b0;
                dist_pow_z=16'b0;
                oct_flag=1'b0;
               
                end
                
            default: begin next_state=idle;
                            lod_ready=0;
                            mem_sram_A=64'b0;
                            //lod_active=5'b0;
                            lod_active_temp=5'b0;
                            dist_pow_x=16'b0;
                            dist_pow_y=16'b0;
                            dist_pow_z=16'b0;
                            oct_flag=1'b0;
                            
            end
        endcase
    end
    always @(posedge clk) begin
        if (lod_active_ready==1)
            lod_active_reg=lod_active_temp;
         else
            lod_active_reg=lod_active_reg;
        if (lod_active_ready_new==1)
            lod_active_reg[4]=lod_active_temp[4];
        else
            lod_active_reg[4]=lod_active_reg[4];
    end
    assign      lod_active           = (lod_ready) ? lod_active_reg[TREE_LEVEL-1:0]:4'b00000;
    
endmodule



