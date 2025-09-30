`timescale 1ns / 1ps

module buadrate(
    input logic clk,
    input logic rst,

    output logic br_tick
);
    logic [$clog2(100_000_000/9600/16)-1:0] br_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            br_counter <= 0;
            br_tick <= 1'b0;
        end else begin
            if (br_counter == 100_000_000 / 9600 / 16 - 1) begin
                br_counter <= 0;
                br_tick <= 1'b1;
            end else begin
                br_counter <= br_counter + 1;
                br_tick <= 1'b0;
            end
        end
    end
endmodule