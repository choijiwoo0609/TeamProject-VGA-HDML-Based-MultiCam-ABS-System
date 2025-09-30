`timescale 1ns / 1ps
// 400KHz의 틱 생성 - i2c 동작 클락
module i2c_tick (
    input   clk,
    input   rstn,
    output reg tick
);
    reg [7:0] count;

    always @(posedge clk, negedge rstn) begin
        if (~rstn) begin
            count <= 0;
            tick  <= 1'b0;

        end else begin
            if (count == 250 - 1) begin
                count <= 0;
                tick  <= 1'b1;
            end else begin
                count <= count + 1;
                tick  <= 1'b0;
            end
        end
    end
endmodule