`timescale 1ns / 1ps

module VGA_MemController (
    input  logic        clk,
    input  logic        reset,
    // VGA side 
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    // frame buffer side 
    output logic        den,
    output logic        cap_val,
    output logic [15:0] led_count,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    //ImgROM side
    input  logic [15:0] Rom_Data,
    // HSV side
    input  logic [ 9:0] h_out,
    input  logic [ 6:0] s_out,
    input  logic [ 6:0] v_out,
    // export side
    output logic [ 3:0] r_port,
    output logic [ 3:0] g_port,
    output logic [ 3:0] b_port
);

    logic [3:0] reg_r, reg_g, reg_b;
    logic reg_cap_val, next_cap_val;
    logic strike, ball;
    logic left_green_val;

    logic [14:0] thr_cnt, thr_cnt_next;

    logic [7:0] startup_delay_cnt;
    logic       system_ready;

    assign cap_val = reg_cap_val;
    assign led_count = {left_green_val, thr_cnt};

    assign reg_r = (rData[15:12] == 0 | rData[15:12] == 4'hf) ? rData[15:12] : rData[15:12] -1;
    assign reg_g = (rData[10:7] == 0 | rData[10:7] == 4'hf) ? rData[10:7] : rData[10:7] -1;
    assign reg_b = rData[4:1];


    assign den = (DE && x_pixel < 640 && y_pixel < 480);  // QVGA Area

    Green_Counter U_Green_Counter (
        .clk           (clk),
        .reset         (reset),
        .den           (den),
        .h_out         (h_out),
        .s_out         (s_out),
        .v_out         (v_out),
        .x_pixel       (x_pixel),
        .y_pixel       (y_pixel),
        .left_green_val(left_green_val)
    );

    typedef enum {
        IDLE,
        RECOGNIZE,
        THROWING
    } state_e;

    state_e state, next_state;

    always_comb begin
        rAddr = 17'bz;
        {r_port, g_port, b_port} = 12'b0;
        if (den) begin
            rAddr = ((y_pixel / 2) * 320 + (x_pixel / 2));
            if (x_pixel >= 200 && x_pixel < 204) begin
                {r_port, g_port, b_port} = 12'b1111_0000_0000;
            end 
            // else if(((h_out >= 10'd10) && (h_out <= 10'd30) &&
            //                             (s_out >= 7'd60) && (s_out <= 7'd100) &&
            //                             (v_out >= 7'd70) && (v_out <= 7'd100)) ||
            //                             ((h_out >= 10'd10) && (h_out <= 10'd10) &&
            //                             (s_out >= 7'd53) && (s_out <= 7'd54) &&
            //                             (v_out >= 7'd100) && (v_out <= 7'd100)) ||
            //                             ((h_out >= 10'd25) && (h_out <= 10'd27) &&
            //                             (s_out >= 7'd62) && (s_out <= 7'd66) &&
            //                             (v_out >= 7'd100) && (v_out <= 7'd100)) ||
            //                             ((h_out >= 10'd2) && (h_out <= 10'd4) &&
            //                             (s_out >= 7'd52) && (s_out <= 7'd55) &&
            //                             (v_out >= 7'd80) && (v_out <= 7'd91))) begin
            //     {r_port, g_port, b_port} = 12'b0000_0000_1111;
            // end 
            else if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                        ((reg_g + 1) >= 1))  begin
                {r_port, g_port, b_port} = {
                    Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                };
            end else begin
                {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            startup_delay_cnt <= 0;
            system_ready      <= 1'b0;
        end else begin
            if (!system_ready) begin
                if ((x_pixel == 639) && (y_pixel == 479)) begin
                    if (startup_delay_cnt < 10) begin
                        startup_delay_cnt <= startup_delay_cnt + 1;
                    end else begin
                        system_ready <= 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            reg_cap_val <= 1'b0;
            thr_cnt     <= 0;
        end else begin
            state       <= next_state;
            reg_cap_val <= next_cap_val;
            thr_cnt     <= thr_cnt_next;
        end
    end

    always_comb begin
        next_state   = state;
        next_cap_val = reg_cap_val;
        thr_cnt_next = thr_cnt;
        case (state)
            IDLE: begin
                next_cap_val = 1'b0;
                if (system_ready && left_green_val) begin
                    next_cap_val = 1;
                    thr_cnt_next = thr_cnt + 1;
                    next_state   = THROWING;
                end
            end
            THROWING: begin
                next_cap_val = 0;
                if ((x_pixel == 639) && (y_pixel == 479) && !(left_green_val))begin
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule


module Green_Counter (
    input  logic       clk,
    input  logic       reset,
    input  logic       den,
    input  logic [9:0] h_out,
    input  logic [6:0] s_out,
    input  logic [6:0] v_out,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    output logic       left_green_val
);
    logic [8:0] left_green_cnt;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            left_green_cnt <= 0;
            left_green_val <= 0;
        end else begin
            if (den) begin
                if (x_pixel < 200) begin
                    if (((h_out >= 10'd10) && (h_out <= 10'd30) &&
                                        (s_out >= 7'd60) && (s_out <= 7'd100) &&
                                        (v_out >= 7'd70) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd10) && (h_out <= 10'd10) &&
                                        (s_out >= 7'd53) && (s_out <= 7'd54) &&
                                        (v_out >= 7'd100) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd25) && (h_out <= 10'd27) &&
                                        (s_out >= 7'd62) && (s_out <= 7'd66) &&
                                        (v_out >= 7'd100) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd2) && (h_out <= 10'd4) &&
                                        (s_out >= 7'd52) && (s_out <= 7'd55) &&
                                        (v_out >= 7'd80) && (v_out <= 7'd91))) begin // r=7, g=b, b=8
                        if (left_green_cnt < 5) begin
                            left_green_cnt <= left_green_cnt + 1;
                        end else begin
                            left_green_val <= 1;
                        end
                    end
                end
            end else begin
                if (y_pixel == 524) begin
                    left_green_cnt <= 0;
                    left_green_val <= 0;
                end
            end
        end
    end
endmodule
// 2~4, 52~55, 80~91
