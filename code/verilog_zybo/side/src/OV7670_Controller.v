`timescale 1ns / 1ps

module OV7670_Controller #(
    parameter IMG_W = 320,
    parameter IMG_H = 240
) (
    input  rstn,
    // ov7670 side
    input  ov_pclk,
    input  href,
    input  vsync,
    input  [7:0] ov7670_data,
    // memory side
    output reg WE,
    output [$clog2(IMG_W*IMG_H)-1:0] wAddr,
    output [15:0] wData
);

    reg [15:0] pixel_data;
    reg [$clog2(IMG_W * 2)-1:0] h_counter;
    reg [$clog2(IMG_H)-1:0] v_counter;

    assign wAddr = v_counter * IMG_W + h_counter[9:1];
    assign wData = pixel_data;

    reg href_s1, href_s2;
    reg vsync_s1, vsync_s2;

    always @(posedge ov_pclk or negedge rstn) begin
        if(~rstn) begin
            {href_s1, href_s2}   <= 0;
            {vsync_s1, vsync_s2} <= 0;
        end else begin
            href_s1  <= href;
            href_s2  <= href_s1;
            vsync_s1 <= vsync;
            vsync_s2 <= vsync_s1;
        end
    end

    always @(posedge ov_pclk or negedge rstn) begin
        if(~rstn) begin
            pixel_data <= 0;
            h_counter <= 0;
            WE <= 1'b0;
        end else begin
            if(href_s2) begin
                h_counter <= h_counter + 1;
                if(h_counter[0] == 0) begin
                    pixel_data[15:8] <= ov7670_data;
                    WE <= 1'b0;
                end else begin
                    pixel_data[7:0] <= ov7670_data;
                    WE <= 1'b1;
                end
            end else begin
                h_counter <= 0;
                WE <= 1'b0;
            end
        end
    end

    always @(posedge ov_pclk or negedge rstn) begin
        if(~rstn) begin
            v_counter <= 0;
        end else begin
            if(vsync_s2) begin
                v_counter <= 0;
            end else begin
                if(h_counter == (320 * 2 - 1)) begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end

    
endmodule