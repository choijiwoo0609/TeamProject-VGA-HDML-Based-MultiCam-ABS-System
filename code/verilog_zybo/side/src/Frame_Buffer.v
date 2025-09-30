`timescale 1ns / 1ps

module Frame_Buffer #(
    parameter IMG_W = 320,
    parameter IMG_H = 240
) (
    // write side
    input ov_pclk,
    input WE,
    input [$clog2(IMG_W * IMG_H)-1:0] wAddr,
    input [15:0] wData,
    // read side
    input pclk,
    input OE,
    input [$clog2(IMG_W * IMG_H)-1:0] rAddr,
    output reg [15:0] rData
);
    
    reg [15:0] mem[0:(IMG_W*IMG_H)-1];

    // write side
    always @(posedge ov_pclk) begin
        if(WE) begin
            mem[wAddr] <= wData;
        end
    end

    // read side
    always @(posedge pclk) begin
        // 출력 에러 발생시 OE if문 제거!
        if(OE) begin
            rData <= mem[rAddr];
        end
    end
endmodule