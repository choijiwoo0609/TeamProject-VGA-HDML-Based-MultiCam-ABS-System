`timescale 1ns / 1ps

module ImgROM #(
    parameter IMG_W = 320,
    parameter IMG_H = 240
) (
    input  [$clog2(IMG_W*IMG_H)-1:0] addr,
    output [15:0]                    data
);

    reg [15:0] mem [0:(IMG_W*IMG_H)-1];

    initial begin
        $readmemh("baseball.mem", mem);
    end

    assign data = mem[addr];

endmodule
