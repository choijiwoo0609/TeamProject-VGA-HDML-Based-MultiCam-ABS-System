`timescale 1ns / 1ps

module Transformer_565_to_888 (
    //input  wire        pclk,
    //input  wire        rstn,
    input  wire [4:0]  r_port_5,
    input  wire [5:0]  g_port_6,
    input  wire [4:0]  b_port_5,
    output reg  [7:0]  r_port_8,
    output reg  [7:0]  g_port_8,
    output reg  [7:0]  b_port_8
);

/*
// 순차 논리 version
always @(posedge pclk or negedge rstn) begin
    if (!rstn) begin
        r_port_8 <= 8'd0;
        g_port_8 <= 8'd0;
        b_port_8 <= 8'd0;
    end else begin
        r_port_8 <= {r_port_5, r_port_5[4:2]};
        g_port_8 <= {g_port_6, g_port_6[5:4]};
        b_port_8 <= {b_port_5, b_port_5[4:2]};
    end
end
*/

// 조합 논리 version
always @(*) begin
    r_port_8 <= {r_port_5, r_port_5[4:2]};
    g_port_8 <= {g_port_6, g_port_6[5:4]};
    b_port_8 <= {b_port_5, b_port_5[4:2]};
end

endmodule
