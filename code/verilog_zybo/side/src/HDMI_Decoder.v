`timescale 1ns / 1ps

module HDMI_Decoder (
    input  wire       pclk,
    input  wire       rstn,
    output wire       h_sync,
    output wire       v_sync,
    output wire [9:0] x_pixel,
    output wire [9:0] y_pixel,
    output wire       DE
);
    localparam H_Visible_area = 640;
    localparam H_Front_porch  = 16;
    localparam H_Sync_pulse   = 96;
    localparam H_Back_porch   = 48;
    localparam H_Whole_line   = 800;

    localparam V_Visible_area = 480;
    localparam V_Front_porch  = 10;
    localparam V_Sync_pulse   = 2;
    localparam V_Back_porch   = 33;
    localparam V_Whole_frame  = 525;

    wire [$clog2(H_Whole_line)-1:0] h_counter;
    wire [$clog2(V_Whole_frame)-1:0] v_counter;

    pixel_counter #(
        .H_MAX(H_Whole_line),
        .V_MAX(V_Whole_frame)
    ) U_PIXEL_COUNTER_0 (
        .pclk(pclk),
        .rstn(rstn),
        .v_counter(v_counter),
        .h_counter(h_counter)
    );

    hdmi_decoder #(
        .H_Visible_area(H_Visible_area),
        .H_Front_porch (H_Front_porch),
        .H_Sync_pulse  (H_Sync_pulse),
        .H_Back_porch  (H_Back_porch),
        .H_Whole_line  (H_Whole_line),
        .V_Visible_area(V_Visible_area),
        .V_Front_porch (V_Front_porch),
        .V_Sync_pulse  (V_Sync_pulse),
        .V_Back_porch  (V_Back_porch),
        .V_Whole_frame (V_Whole_frame)
    ) U_HDMI_DECODER_0 (
        .h_counter(h_counter),
        .v_counter(v_counter),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .DE(DE)
    );

endmodule


module pixel_counter #(
    parameter H_MAX = 800,
    parameter V_MAX = 525
) (
    input  wire pclk,
    input  wire rstn,
    output reg  [$clog2(H_MAX)-1:0] h_counter,
    output reg  [$clog2(V_MAX)-1:0] v_counter
);

    always @(negedge pclk or negedge rstn) begin
        if (!rstn) begin
            h_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                h_counter <= 0;
            end else begin
                h_counter <= h_counter + 1;
            end
        end
    end

    always @(negedge pclk or negedge rstn) begin
        if (!rstn) begin
            v_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                if (v_counter == V_MAX - 1) begin
                    v_counter <= 0;
                end else begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule


module hdmi_decoder #(
    parameter H_Visible_area = 640,
    parameter H_Front_porch  = 16,
    parameter H_Sync_pulse   = 96,
    parameter H_Back_porch   = 48,
    parameter H_Whole_line   = 800,

    parameter V_Visible_area = 480,
    parameter V_Front_porch  = 10,
    parameter V_Sync_pulse   = 2,
    parameter V_Back_porch   = 33,
    parameter V_Whole_frame  = 525
) (
    input  wire [$clog2(H_Whole_line)-1:0] h_counter,
    input  wire [$clog2(V_Whole_frame)-1:0] v_counter,
    output wire                            h_sync,
    output wire                            v_sync,
    output wire [$clog2(H_Whole_line)-1:0] x_pixel,
    output wire [$clog2(V_Whole_frame)-1:0] y_pixel,
    output wire                            DE
);

    assign h_sync = ((h_counter >= H_Visible_area + H_Front_porch) &&
                     (h_counter <  H_Visible_area + H_Front_porch + H_Sync_pulse)) ? 1'b0 : 1'b1;

    assign v_sync = ((v_counter >= V_Visible_area + V_Front_porch) &&
                     (v_counter <  V_Visible_area + V_Front_porch + V_Sync_pulse)) ? 1'b0 : 1'b1;

    assign DE = ((h_counter < H_Visible_area) && (v_counter < V_Visible_area)) ? 1'b1 : 1'b0;

    assign x_pixel = h_counter;
    assign y_pixel = v_counter;

endmodule
