
module sram_input #(
    parameter data_width = 4*16,
    parameter addr_width = 7,
    parameter depth      = 128
)(
    input  logic clk,
    input  logic cen_n,
    input  logic wen,
    input  logic [addr_width-1:0] addr,
    input  logic [data_width-1:0] data_in,
    output logic [data_width-1:0] data_out
);

    logic [data_width-1:0] mem [0:depth-1];

    assign mem[21]=64'h3800380038000000;    //0.5, 0.5, 0.5 ; 2.5, 2.5, 22 ; 89, 89, 70
                                        

    assign mem[22]=64'h222222222222222;
    assign mem[23]=64'h233333333333333;
    assign mem[24]=64'h244444444444444;
    assign mem[25]=64'h255555555555555;
    assign mem[26]=64'h266666666666666;
    assign mem[27]=64'h277777777777777;
    assign mem[28]=64'h288888888888888;
    assign mem[29]=64'h299999999999999;
    assign mem[30]=64'h2aaaaaaaaaaaaaa;

    assign mem[31]=64'h38ed38ed388d0000;    //0.616,0.616, 0.569; 2.8, 2.8, 25 (被遮挡)

    assign mem[32]=64'h322222222222222;     
    assign mem[33]=64'h333333333333333;
    assign mem[34]=64'h344444444444444;
    assign mem[35]=64'h355555555555555;
    assign mem[36]=64'h366666666666666;
    assign mem[37]=64'h377777777777777;
    assign mem[38]=64'h388888888888888;
    assign mem[39]=64'h399999999999999;
    assign mem[40]=64'h3aaaaaaaaaaaaaa;

    assign mem[41]=64'h3e00380034000000;    //1.5, 0.5, 0.25 ;3.25, 3.25, 13; 102, 102, 43

    assign mem[42]=64'h422222222222222;
    assign mem[43]=64'h433333333333333;
    assign mem[44]=64'h444444444444444;
    assign mem[45]=64'h455555555555555;
    assign mem[46]=64'h466666666666666;
    assign mem[47]=64'h477777777777777;
    assign mem[48]=64'h488888888888888;
    assign mem[49]=64'h499999999999999;
    assign mem[50]=64'h4aaaaaaaaaaaaaa;

    assign mem[51]=64'h52404b804f000000; //50, 15, 28

    assign mem[52]=64'h522222222222222;
    assign mem[53]=64'h533333333333333;
    assign mem[54]=64'h544444444444444;
    assign mem[55]=64'h555555555555555;
    assign mem[56]=64'h566666666666666;
    assign mem[57]=64'h577777777777777;
    assign mem[58]=64'h588888888888888;
    assign mem[59]=64'h599999999999999;
    assign mem[60]=64'h5aaaaaaaaaaaaaa;

    assign mem[61]=64'hc900c40034000000; //-10, -4, 0.25; -12.75, -12.75; -3

    assign mem[62]=64'h622222222222222;
    assign mem[63]=64'h633333333333333;
    assign mem[64]=64'h644444444444444;
    assign mem[65]=64'h655555555555555;
    assign mem[66]=64'h666666666666666;
    assign mem[67]=64'h677777777777777;
    assign mem[68]=64'h688888888888888;
    assign mem[69]=64'h699999999999999;
    assign mem[70]=64'h6aaaaaaaaaaaaaa;

    assign mem[71]=64'h3e003e0038000000; //1.5, 1.5, 0.5; 4.5, 4.5, 24 //

    assign mem[72]=64'h722222222222222;
    assign mem[73]=64'h733333333333333;
    assign mem[74]=64'h744444444444444;
    assign mem[75]=64'h755555555555555;
    assign mem[76]=64'h766666666666666;
    assign mem[77]=64'h777777777777777;
    assign mem[78]=64'h788888888888888;
    assign mem[79]=64'h799999999999999;
    assign mem[80]=64'h7aaaaaaaaaaaaaa;

    always_ff @(posedge clk) begin
        if (!cen_n) begin
            if (wen) begin
                mem[addr] <= data_in;
            end 
            data_out <= mem[addr];
        end
    end
endmodule