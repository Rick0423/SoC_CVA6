`timescale 1ns / 1ps
module control(
    input logic clk,
    input logic rst_n,
    input logic start1,
    input logic done1,
    input logic start2,
    input logic done2,
    input logic start3,
    input logic done3,
    output logic [1:0] choose
);
    logic doing1,doing2,doing3;
    always @(posedge clk) begin
        if (~rst_n) begin
            doing1<=0;
        end else if (start1) begin
            doing1<=1;
        end else if (done1) begin
            doing1<=0;
        end
    end
    always @(posedge clk) begin
        if (~rst_n) begin
            doing2<=0;
        end else if (start2) begin
            doing2<=1;
        end else if (done2) begin
            doing2<=0;
        end
    end
    always @(posedge clk) begin
        if (~rst_n) begin
            doing3<=0;
        end else if (start3) begin
            doing3<=1;
        end else if (done3) begin
            doing3<=0;
        end
    end
    assign choose= (doing1==1) ? 2'b01 :
                    (doing2==1) ? 2'b10 :
                    (doing3==1) ? 2'b11 : 2'b00;
endmodule