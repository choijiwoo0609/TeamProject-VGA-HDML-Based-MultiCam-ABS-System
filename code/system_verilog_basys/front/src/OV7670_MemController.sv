`timescale 1ns / 1ps

/*
module OV7670_MemController (
    input  logic        clk,
    input  logic        reset,
    // ov7670 side
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] ov7670_data,
    // memory side
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);

    logic [15:0] pixel_data;
    logic [ 9:0] h_counter;
    logic [ 7:0] v_counter;

    assign wAddr = v_counter * 320 + h_counter[9:1];
    assign wData = pixel_data;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            h_counter <= 0;
            pixel_data <= 0;
            we <= 0;
        end else begin
            if (href) begin
                h_counter <= h_counter + 1;
                if (!h_counter[0]) begin
                    pixel_data[15:8] <= ov7670_data;
                    we <= 1'b0;
                end else begin
                    pixel_data[7:0] <= ov7670_data;
                    we <= 1'b1;
                end
            end else begin
                h_counter <= 0;
                we <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (vsync) begin
                v_counter <= 0;
            end else begin
                if (h_counter == (320 * 2) - 1) begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end

endmodule
*/


module OV7670_MemController (
    input  logic        clk,
    input  logic        reset,
    // ov7670 side
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] ov7670_data,
    // memory side
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);

    logic [15:0] pixel_data;
    logic [ 9:0] h_counter;
    logic [ 7:0] v_counter;

    // ★★★ 핵심 수정 사항 1: 동기화 로직 추가 ★★★
    logic href_s1, href_s2;
    logic vsync_s1, vsync_s2;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            {href_s1, href_s2}   <= 0;
            {vsync_s1, vsync_s2} <= 0;
        end else begin
            href_s1  <= href;
            href_s2  <= href_s1;
            vsync_s1 <= vsync;
            vsync_s2 <= vsync_s1;
        end
    end
    // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★

    assign wData = pixel_data;

    // 이제부터는 href 대신 href_s2, vsync 대신 vsync_s2를 사용합니다.

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            pixel_data <= 0;
            h_counter  <= 0;
            we         <= 1'b0;
            wAddr      <= 0;
        end else begin
            // ★★★ 수정: href -> href_s2
            if (href_s2) begin 
                h_counter <= h_counter + 1;
                wAddr     <= v_counter * 320 + h_counter[9:1];

                if (h_counter[0] == 0) begin
                    pixel_data[15:8] <= ov7670_data;
                    we <= 1'b0;
                end else begin
                    pixel_data[7:0] <= ov7670_data;
                    we <= 1'b1;
                end
            end else begin
                h_counter <= 0;
                we <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            v_counter <= 0;
        end else begin
            // ★★★ 수정: vsync -> vsync_s2
            if (vsync_s2) begin 
                v_counter <= 0;
            end else begin
                // 라인의 끝을 감지할 때도 동기화된 href_s2를 사용해야 합니다.
                // 이전 href_s2 값과 현재 href_s2 값을 비교하여 falling edge를 감지하는 것이 더 안정적입니다.
                // 여기서는 h_counter를 사용하므로 큰 문제는 없습니다.
                if (h_counter == (320 * 2 - 1)) begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule