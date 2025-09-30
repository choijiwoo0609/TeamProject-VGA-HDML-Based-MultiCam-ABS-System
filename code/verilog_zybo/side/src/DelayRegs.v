`timescale 1ns / 1ps

module DelayRegs(
    input  wire pclk,
    input  wire rstn,
    input  wire de_in,
    input  wire hs_in,
    input  wire vs_in,
    output reg  de_out,
    output reg  hs_out,
    output reg  vs_out
);

always @(posedge pclk or negedge rstn) begin
    if (!rstn) begin
        de_out <= 1'b0;
        hs_out <= 1'b0;
        vs_out <= 1'b0;
    end else begin
        de_out <= de_in;
        hs_out <= hs_in;
        vs_out <= vs_in;
    end
end

endmodule
