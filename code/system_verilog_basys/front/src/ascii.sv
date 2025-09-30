`timescale 1ns / 1ps

module ascii (
    input  logic       Strike,
    input  logic       Ball,
    output logic [7:0] ascii
);

    always_comb begin
        if (Strike) ascii <= 8'd83;  // 'S'
        else if (Ball) ascii <= 8'd66;  // 'B'
        else ascii <= 8'd79;  // 'O'
    end

endmodule
