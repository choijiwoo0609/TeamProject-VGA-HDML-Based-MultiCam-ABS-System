`timescale 1ns / 1ps


module VGA_MemController (
    input  logic        vga_pclk,
    input  logic        reset,
    input  logic        btn_red,
    input  logic        btn_rf,
    input  logic        btn_chr,
    input  logic        f2s_val_out,
    input  logic [ 3:0] sw_r,
    input  logic [ 3:0] sw_g,
    input  logic [ 3:0] sw_b,
    // VGA side
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    // frame buffer side
    output logic        den,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    input  logic [15:0] Rom_Data,
    //uart side
    input  logic        rx_done,
    input  logic [ 7:0] rx_data,
    // export side 
    output logic [ 3:0] r_port,
    output logic [ 3:0] g_port,
    output logic [ 3:0] b_port,
    output logic        led_red,
    output logic        led_green,
    output logic [ 1:0] led_strike,
    output logic [ 2:0] led_ball,
    output logic        f2s_en_out,
    output logic        Strike,
    output logic        Ball,
    output logic        ball_pos_1,
    output logic        ball_pos_2,
    output logic        ball_pos_3,
    output logic        ball_pos_4,
    output logic        ball_pos_5,
    output logic        ball_pos_6,
    output logic        ball_pos_7,
    output logic        ball_pos_8,
    output logic        ball_pos_9
);

    parameter int X_START = 200;
    parameter int X_END = X_START + 100;
    //parameter int Y_START = 200;
    //parameter int Y_END = Y_START + 150;
    parameter int BORDER = 3;
    parameter int GRID_X = (X_END - X_START) / 3;
    //parameter int GRID_Y = (Y_END - Y_START) / 3;
    parameter int CIRCLE_X = 240;
    parameter int CIRCLE_Y = 100;
    parameter int RADIUS = 20;

    typedef enum {
        IDLE,
        ONE,
        TWO,
        THREE,
        FOUR
    } state_e;

    logic red_val;
    logic [3:0] reg_r, reg_g, reg_b;
    logic [9:0] red_y;
    logic [8:0] red_top_y_next, red_bot_y_next;
    logic [8:0] red_top_y_reg, red_bot_y_reg;
    logic red_flag, red_flag_next;

    logic [8:0] GRID_Y_RED, GRID_Y_RED_NEXT;
    logic green_val;

    logic [1:0] Strike_Cnt, Strike_Cnt_next;
    logic [2:0] Ball_Cnt, Ball_Cnt_next;
    logic f2s_en, f2s_en_next;

    logic mode_change;

    logic [9:0] h_out;
    logic [6:0] s_out;
    logic [6:0] v_out;

    logic [9:0] chr_left_cnt_next, chr_left_cnt;
    logic [9:0] chr_right_cnt_next, chr_right_cnt;
    logic [9:0] chr_min_x, chr_max_x;
    logic [9:0] chr_min_x_reg, chr_min_x_reg_next;
    logic [9:0] chr_max_x_reg, chr_max_x_reg_next;
    logic chr_min_x_flag, chr_min_x_flag_next;
    logic chr_max_x_flag, chr_max_x_flag_next;

    state_e state, next_state;

    assign f2s_en_out = f2s_en;
    assign led_red = red_val;
    assign led_green = green_val;
    assign led_strike = Strike_Cnt;
    assign led_ball = Ball_Cnt;

    assign reg_r = ((rData[15:12] == 4'hf) | (rData[15:12] == 0)) ? rData[15:12] : rData[15:12] - 1;
    assign reg_g = ((rData[10:7] == 4'hf) | (rData[10:7] == 0)) ? rData[10:7] : rData[10:7] - 1;
    assign reg_b = rData[4:1];

    assign den = DE && x_pixel < 640 && y_pixel < 480;  // QVGA Area
    assign rAddr = den ? ((y_pixel / 2) * 320 + (x_pixel / 2)) : 17'bz;
    // assign {r_port, g_port, b_port} = den ? {rData[15:12], rData[10:7], rData[4:1]} : 12'b0;

    always_ff @(posedge vga_pclk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            red_top_y_reg <= 0;
            red_bot_y_reg <= 0;
            Strike_Cnt <= 0;
            Ball_Cnt <= 0;
            GRID_Y_RED <= 0;
            f2s_en <= 0;
            red_flag <= 0;
            chr_left_cnt <= 0;
            chr_right_cnt <= 0;
            chr_min_x_flag <= 0;
            chr_max_x_flag <= 0;
            chr_min_x_reg <= 0;
            chr_max_x_reg <= 0;
        end else begin
            state <= next_state;
            red_top_y_reg <= red_top_y_next;
            red_bot_y_reg <= red_bot_y_next;
            Strike_Cnt <= Strike_Cnt_next;
            Ball_Cnt <= Ball_Cnt_next;
            GRID_Y_RED <= GRID_Y_RED_NEXT;
            f2s_en <= f2s_en_next;
            red_flag <= red_flag_next;
            chr_left_cnt <= chr_left_cnt_next;
            chr_right_cnt <= chr_right_cnt_next;
            chr_min_x_flag <= chr_min_x_flag_next;
            chr_max_x_flag <= chr_max_x_flag_next;
            chr_min_x_reg <= chr_min_x_reg_next;
            chr_max_x_reg <= chr_max_x_reg_next;
        end
    end

    always_comb begin
        next_state = state;
        red_top_y_next = red_top_y_reg;
        red_bot_y_next = red_bot_y_reg;
        Strike_Cnt_next = Strike_Cnt;
        Ball_Cnt_next = Ball_Cnt;
        GRID_Y_RED_NEXT = GRID_Y_RED;
        f2s_en_next = f2s_en;
        red_flag_next = red_flag;
        chr_left_cnt_next = chr_left_cnt;
        chr_right_cnt_next = chr_right_cnt;
        chr_min_x_flag_next = chr_min_x_flag;
        chr_max_x_flag_next = chr_max_x_flag;
        chr_min_x_reg_next = chr_min_x_reg;
        chr_max_x_reg_next = chr_max_x_reg;
        Strike = 0;
        Ball = 0;
        {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
        case (state)
            IDLE: begin
                chr_left_cnt_next   = 0;
                chr_right_cnt_next  = 640 - BORDER;
                red_flag_next       = 0;
                f2s_en_next         = 0;
                chr_min_x_flag_next = 0;
                chr_max_x_flag_next = 0;
                chr_min_x_reg_next  = 0;
                chr_max_x_reg_next  = 640;
                if (red_val) begin
                    red_top_y_next = 480 - red_y + (red_y >> 1) + (red_y >> 2);
                    red_bot_y_next = 480 - red_y + (red_y >> 1);
                    next_state = ONE;
                end
            end
            ONE: begin
                f2s_en_next = 0;
                GRID_Y_RED_NEXT = (red_top_y_reg - red_bot_y_reg) / 3;
                if (btn_chr) begin
                    chr_min_x_reg_next = chr_min_x;
                    chr_max_x_reg_next = chr_max_x;
                    next_state = THREE;
                end
                if (btn_red) begin
                    if (red_flag) begin
                        next_state = FOUR;
                    end else begin
                        red_flag_next = 1;
                    end
                end
                if (red_flag) begin
                    if (den) begin
                        if ((x_pixel >= X_START) && (x_pixel <= X_END) &&
                            (y_pixel >= red_bot_y_reg) && (y_pixel <= red_top_y_reg)) begin
                            // 바깥 테두리
                            if ((x_pixel < X_START + BORDER) || (x_pixel > X_END - BORDER) ||
                                (y_pixel < red_bot_y_reg + BORDER) || (y_pixel > red_top_y_reg - BORDER)) begin
                                {r_port, g_port, b_port} = 12'hFFF;
                            end  // 내부 세로 격자선 (X축 기준)
                            else if (((x_pixel >= X_START + GRID_X - (BORDER/2)) &&
                                    (x_pixel <= X_START + GRID_X + (BORDER/2))) ||
                                    ((x_pixel >= X_START + 2*GRID_X - (BORDER/2)) &&
                                    (x_pixel <= X_START + 2*GRID_X + (BORDER/2))) ) begin
                                {r_port, g_port, b_port} = 12'hFFF;
                            end  // 내부 가로 격자선 (Y축 기준)
                            else if (((y_pixel >= red_bot_y_reg + GRID_Y_RED - (BORDER/2)) &&
                                    (y_pixel <= red_bot_y_reg + GRID_Y_RED + (BORDER/2))) ||
                                    ((y_pixel >= red_bot_y_reg + 2*GRID_Y_RED - (BORDER/2)) &&
                                    (y_pixel <= red_bot_y_reg + 2*GRID_Y_RED + (BORDER/2))) ) begin
                                {r_port, g_port, b_port} = 12'hFFF;
                            end else begin
                                // 내부 배경
                                if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                                    ((reg_g + 1) >= 1)) begin
                                    {r_port, g_port, b_port} = {
                                        Rom_Data[15:12],
                                        Rom_Data[10:7],
                                        Rom_Data[4:1]
                                    };
                                end else begin
                                    {r_port, g_port, b_port} = {
                                        reg_r, reg_g, reg_b
                                    };
                                end
                            end
                        end else if ((x_pixel < chr_min_x_reg) | (x_pixel > chr_max_x_reg)) begin
                            {r_port, g_port, b_port} = {
                                Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                            };
                        end else if ((x_pixel >= chr_min_x_reg) | (x_pixel <= chr_max_x_reg)) begin
                            if (((h_out >= 10'd300) && (h_out <= 10'd360) || (h_out >= 10'd0) && (h_out <= 10'd20)) && (s_out >= 7'd45) && (v_out >= 7'd60)) begin
                                {r_port, g_port, b_port} = 12'h008;
                            end else if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                              ((reg_g + 1) >= 1)) begin
                                {r_port, g_port, b_port} = {
                                    Rom_Data[15:12],
                                    Rom_Data[10:7],
                                    Rom_Data[4:1]
                                };
                            end else begin
                                {r_port, g_port, b_port} = {
                                    reg_r, reg_g, reg_b
                                };
                            end
                        end else begin
                            {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                        end
                    end else begin
                        {r_port, g_port, b_port} = 12'b0;
                    end
                end 
                else if ((x_pixel < chr_min_x_reg) | (x_pixel > chr_max_x_reg)) begin
                    {r_port, g_port, b_port} = {
                        Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                    };
                end else begin
                    {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                end
                if (btn_rf) begin
                    f2s_en_next = 1;
                end
                if (f2s_val_out && (y_pixel >= 524)) begin
                    if (green_val) begin
                        Strike = 1;
                        Strike_Cnt_next = Strike_Cnt + 1;
                    end else begin
                        Ball = 1;
                        Ball_Cnt_next = Ball_Cnt + 1;
                    end
                    next_state = TWO;
                end
            end
            TWO: begin
                if (den) begin
                    if ((x_pixel >= X_START) && (x_pixel <= X_END) &&
                            (y_pixel >= red_bot_y_reg) && (y_pixel <= red_top_y_reg)) begin
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
                                        (v_out >= 7'd80) && (v_out <= 7'd91))) begin
                            {r_port, g_port, b_port} = 12'h800;
                        end  // 바깥 테두리
                        else if ((x_pixel < X_START + BORDER) || (x_pixel > X_END - BORDER) ||
                                (y_pixel < red_bot_y_reg + BORDER) || (y_pixel > red_top_y_reg - BORDER)) begin
                            {r_port, g_port, b_port} = 12'hFFF;
                        end  // 내부 세로 격자선 (X축 기준)
                            else if ( ((x_pixel >= X_START + GRID_X - (BORDER/2)) &&
                                    (x_pixel <= X_START + GRID_X + (BORDER/2))) ||
                                    ((x_pixel >= X_START + 2*GRID_X - (BORDER/2)) &&
                                    (x_pixel <= X_START + 2*GRID_X + (BORDER/2))) ) begin
                            {r_port, g_port, b_port} = 12'hFFF;
                        end  // 내부 가로 격자선 (Y축 기준)
                            else if ( ((y_pixel >= red_bot_y_reg + GRID_Y_RED - (BORDER/2)) &&
                                    (y_pixel <= red_bot_y_reg + GRID_Y_RED + (BORDER/2))) ||
                                    ((y_pixel >= red_bot_y_reg + 2*GRID_Y_RED - (BORDER/2)) &&
                                    (y_pixel <= red_bot_y_reg + 2*GRID_Y_RED + (BORDER/2))) ) begin
                            {r_port, g_port, b_port} = 12'hFFF;
                        end else if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                              ((reg_g + 1) >= 1)) begin
                            {r_port, g_port, b_port} = {
                                Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                            };
                        end else begin
                            // 내부 배경
                            {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                        end
                    end else if ((x_pixel < chr_min_x_reg) | (x_pixel > chr_max_x_reg)) begin
                        {r_port, g_port, b_port} = {
                            Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                        };
                    end else begin
                        if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                              ((reg_g + 1) >= 1)) begin
                            {r_port, g_port, b_port} = {
                                Rom_Data[15:12], Rom_Data[10:7], Rom_Data[4:1]
                            };
                        end else begin
                            {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                        end
                    end
                end else begin
                    {r_port, g_port, b_port} = 12'b0;
                end
                if (!f2s_val_out) begin
                    if ((Strike_Cnt == 3) | (Ball_Cnt == 4)) begin
                        next_state = FOUR;
                        Strike_Cnt_next = 0;
                        Ball_Cnt_next = 0;
                        Strike = 0;
                        Ball = 0;
                    end else begin
                        next_state = ONE;
                    end
                end
            end
            THREE: begin
                if (den) begin
                    if (x_pixel <= chr_min_x_reg) begin
                        if ((x_pixel >= chr_left_cnt) & (x_pixel <= chr_left_cnt + BORDER)) begin
                            {r_port, g_port, b_port} = 12'hfff;
                        end else begin
                            {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                        end
                        if (chr_left_cnt + BORDER < chr_min_x_reg) begin
                            if (!x_pixel & !y_pixel) begin
                                chr_left_cnt_next = chr_left_cnt + 1;
                            end
                        end else begin
                            chr_min_x_flag_next = 1;
                        end
                    end else if (x_pixel >= chr_max_x_reg) begin
                        if ((x_pixel >= chr_right_cnt) & (x_pixel <= chr_right_cnt + BORDER)) begin
                            {r_port, g_port, b_port} = 12'hfff;
                        end else begin
                            {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                        end
                        if (chr_right_cnt > chr_max_x_reg) begin
                            if ((x_pixel == 639) & (y_pixel == 479)) begin
                                chr_right_cnt_next = chr_right_cnt - 1;
                            end
                        end else begin
                            chr_max_x_flag_next = 1;
                        end
                    end else begin
                        {r_port, g_port, b_port} = {reg_r, reg_g, reg_b};
                    end
                end
                if (chr_min_x_flag & chr_max_x_flag) begin
                    chr_min_x_flag_next = 0;
                    chr_max_x_flag_next = 0;
                    next_state = ONE;
                end
            end
            FOUR: begin
                chr_left_cnt_next   = 0;
                chr_right_cnt_next  = 640 - BORDER;
                red_flag_next       = 0;
                f2s_en_next         = 0;
                chr_min_x_flag_next = 0;
                chr_max_x_flag_next = 0;
                if (red_val) begin
                    red_top_y_next = 480 - red_y + (red_y >> 1) + (red_y >> 2);
                    red_bot_y_next = 480 - red_y + (red_y >> 1);
                    next_state = ONE;
                end
            end
        endcase
    end

    Red_Counter U_Red_Counter (
        .clk    (vga_pclk),
        .reset  (reset),
        .h_out  (h_out),
        .s_out  (s_out),
        .v_out  (v_out),
        .den    (den),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .rData  (rData),
        .red_val(red_val),
        .red_y  (red_y)
    );

    Green_Counter #(
        .X_START(300),
        .X_END  (400)
    ) U_Green_Counter (
        .clk          (vga_pclk),
        .reset        (reset),
        .en           ((state == ONE)),
        .den          (den),
        .h_out        (h_out),
        .s_out        (s_out),
        .v_out        (v_out),
        .x_pixel      (x_pixel),
        .y_pixel      (y_pixel),
        .red_top_y_reg(red_top_y_reg),
        .red_bot_y_reg(red_bot_y_reg),
        .green_val    (green_val)
    );

    RGB_to_HSV(
        .rData(rData),  // RGB (R:5, G:6, B:5)
        .h_out(h_out),  // Hue (0-360 degrees)
        .s_out(s_out),  // Saturation (0-100%)
        .v_out(v_out)  // Value (0-100%)
    );

    ChromaKey_Detector U_ChromaKey_Detector (
        .vga_pclk(vga_pclk),
        .reset(reset),
        .en(state == ONE),
        .den(den),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .reg_r(reg_r),
        .reg_b(reg_b),
        .reg_g(reg_g),
        .h_out(h_out),
        .s_out(s_out),
        .v_out(v_out),
        .chr_min_x(chr_min_x),
        .chr_max_x(chr_max_x)
    );

    Ball_Position #(
        .X_START(X_START),
        .X_END  (X_END)
    ) U_Ball_Position (
        .vga_pclk(vga_pclk),
        .reset(reset),
        .en(f2s_val_out),
        .den(den),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .h_out(h_out),
        .s_out(s_out),
        .v_out(v_out),
        .red_bot_y_reg(red_bot_y_reg),
        .red_top_y_reg(red_top_y_reg),
        .ball_pos_1(ball_pos_1),
        .ball_pos_2(ball_pos_2),
        .ball_pos_3(ball_pos_3),
        .ball_pos_4(ball_pos_4),
        .ball_pos_5(ball_pos_5),
        .ball_pos_6(ball_pos_6),
        .ball_pos_7(ball_pos_7),
        .ball_pos_8(ball_pos_8),
        .ball_pos_9(ball_pos_9)
    );

    mode_change U_Mode_Change (
        .clk        (vga_pclk),
        .reset      (reset),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .mode_change(mode_change)
    );
endmodule


module Red_Counter (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 9:0] h_out,
    input  logic [ 6:0] s_out,
    input  logic [ 6:0] v_out,
    input  logic        den,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [15:0] rData,
    output logic        red_val,
    output logic [ 9:0] red_y
);

    localparam IDLE = 0, ONE = 1;

    logic [3:0] red_cnt;
    logic state, next_state;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            red_cnt <= 0;
            red_val <= 0;
            red_y <= 0;
            state <= IDLE;
            next_state <= IDLE;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (den) begin
                        if (((h_out >= 10'd0) && (h_out <= 10'd10) &&
                                        (s_out >= 7'd80) && (s_out <= 7'd85) &&
                                        (v_out >= 7'd46) && (v_out <= 7'd50))) begin // r=12, g=7, b=9
                            if (red_cnt < 10) begin
                                red_cnt <= red_cnt + 1;
                            end else begin
                                red_val <= 1;
                                red_y <= 480 - y_pixel;
                                next_state <= ONE;
                            end
                        end
                    end
                end
                ONE: begin
                    if (y_pixel >= 524) begin
                        red_cnt <= 0;
                        red_val <= 0;
                        next_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule


module Green_Counter #(
    parameter X_START = 300,
    parameter X_END   = 400
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       en,
    input  logic       den,
    input  logic [9:0] h_out,
    input  logic [6:0] s_out,
    input  logic [6:0] v_out,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [8:0] red_top_y_reg,
    input  logic [8:0] red_bot_y_reg,
    output logic       green_val
);

    logic [5:0] green_cnt;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            green_cnt <= 0;
            green_val <= 0;
        end else begin
            if (en) begin
                if (den) begin
                    if(((x_pixel > X_START) && (x_pixel < X_END)) && ((y_pixel > red_bot_y_reg) && (y_pixel < red_top_y_reg)))
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
                            if (green_cnt < 35) begin
                                green_cnt <= green_cnt + 1;
                            end else begin
                                green_val <= 1;
                            end
                        end
                end else begin
                    if (y_pixel >= 524) begin
                        green_cnt <= 0;
                        green_val <= 0;
                    end
                end
            end
        end
    end

endmodule


module Ball_Position #(
    parameter X_START = 300,
    parameter X_END   = 400
) (
    input  logic       vga_pclk,
    input  logic       reset,
    input  logic       en,
    input  logic       den,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [9:0] h_out,
    input  logic [6:0] s_out,
    input  logic [6:0] v_out,
    input  logic [9:0] red_bot_y_reg,
    input  logic [9:0] red_top_y_reg,
    output logic       ball_pos_1,
    output logic       ball_pos_2,
    output logic       ball_pos_3,
    output logic       ball_pos_4,
    output logic       ball_pos_5,
    output logic       ball_pos_6,
    output logic       ball_pos_7,
    output logic       ball_pos_8,
    output logic       ball_pos_9
);

    logic [8:0] y_offset;
    logic total_en;

    assign y_offset = red_top_y_reg - red_bot_y_reg;
    assign total_en = (en &&
    ((h_out >= 10'd170) && (h_out <= 10'd512)  && (s_out >= 7'd38)  && (s_out <= 7'd127) && (v_out >= 7'd38)  && (v_out <= 7'd127)));

    always_ff @(posedge vga_pclk, posedge reset) begin
        if (reset) begin
            ball_pos_1 <= 0;
            ball_pos_2 <= 0;
            ball_pos_3 <= 0;
            ball_pos_4 <= 0;
            ball_pos_5 <= 0;
            ball_pos_6 <= 0;
            ball_pos_7 <= 0;
            ball_pos_8 <= 0;
            ball_pos_9 <= 0;
        end else begin
            if (total_en) begin
                if (x_pixel > 300 && x_pixel <= 333) begin
                    case (y_pixel) inside
                        [red_bot_y_reg : red_bot_y_reg + (y_offset / 3)]: begin
                            ball_pos_1 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3) + 1 : red_bot_y_reg + (y_offset / 3 * 2)]: begin
                            ball_pos_4 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3 * 2) + 1 : red_bot_y_reg + y_offset]: begin
                            ball_pos_7 <= 1;
                        end
                    endcase
                end
                if (x_pixel > 334 && x_pixel <= 366) begin
                    case (y_pixel) inside
                        [red_bot_y_reg : red_bot_y_reg + (y_offset / 3)]: begin
                            ball_pos_2 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3) + 1 : red_bot_y_reg + (y_offset / 3 * 2)]: begin
                            ball_pos_5 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3 * 2) + 1 : red_bot_y_reg + y_offset]: begin
                            ball_pos_8 <= 1;
                        end
                    endcase
                end
                if (x_pixel > 367 && x_pixel <= 400) begin
                    case (y_pixel) inside
                        [red_bot_y_reg : red_bot_y_reg + (y_offset / 3)]: begin
                            ball_pos_3 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3) + 1 : red_bot_y_reg + (y_offset / 3 * 2)]: begin
                            ball_pos_6 <= 1;
                        end

                        [red_bot_y_reg + (y_offset / 3 * 2) + 1 : red_bot_y_reg + y_offset]: begin
                            ball_pos_9 <= 1;
                        end
                    endcase
                end
            end
            if (!en && (y_pixel >= 524)) begin
                ball_pos_1 <= 0;
                ball_pos_2 <= 0;
                ball_pos_3 <= 0;
                ball_pos_4 <= 0;
                ball_pos_5 <= 0;
                ball_pos_6 <= 0;
                ball_pos_7 <= 0;
                ball_pos_8 <= 0;
                ball_pos_9 <= 0;
            end
        end
    end
endmodule

module mode_change (
    input logic clk,
    input logic reset,
    input logic [7:0] rx_data,
    input logic rx_done,
    output logic mode_change
);

    logic mode_change1, mode_change2;

    assign mode_change = (!mode_change1 & mode_change2);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            mode_change1 <= 0;
        end else begin
            if (rx_done) begin
                if (rx_data == "m") begin
                    mode_change1 <= 1;
                end else begin
                    mode_change1 <= 0;
                end
            end else begin
                mode_change1 <= 0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            mode_change2 <= 0;
        end else begin
            mode_change2 <= mode_change1;
        end
    end
endmodule
