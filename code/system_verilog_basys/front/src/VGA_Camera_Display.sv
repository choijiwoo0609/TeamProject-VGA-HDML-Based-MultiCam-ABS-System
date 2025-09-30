`timescale 1ns / 1ps


module VGA_Camera_Display (
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_gray,
    input  logic       btn_red,
    input  logic       btn_chr,
    input  logic [3:0] sw_r,
    input  logic [3:0] sw_g,
    input  logic [3:0] sw_b,
    // ov7670 side
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_vsync,
    input  logic [7:0] ov7670_data,
    // external port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       led_red,
    output logic       led_green,
    output logic [1:0] led_strike,
    output logic [2:0] led_ball,
    output logic       led_f2s,
    output logic       ov7670_scl,
    output logic       ov7670_sda,
    input  logic       rx,
    output logic       tx,
    // rf port
    output logic       nrf_sclk,
    output logic       nrf_mosi,
    input  logic       nrf_miso,
    output logic       nrf_csn,
    output logic       nrf_ce,
    input  logic       nrf_irq_n,
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

    logic        ov7670_we;
    logic [16:0] ov7670_wAddr;
    logic [15:0] ov7670_wData;

    logic        vga_pclk;
    logic [ 9:0] vga_x_pixel;
    logic [ 9:0] vga_y_pixel;
    logic        vga_DE;

    logic        vga_den;
    logic [16:0] vga_rAddr;
    logic [15:0] vga_rData;

    logic [3:0] vga_r, vga_b, vga_g;
    logic [3:0] gray_r, gray_b, gray_g;

    logic        obtn;

    logic [15:0] Rom_Data;

    logic        rf_val;

    logic [ 7:0] rx_data;
    logic        rx_done;

    assign ov7670_xclk = vga_pclk;

    TOP_sccb_ctrl U_TOP_sccb_ctrl (
        .clk(clk),
        .reset(reset),
        .ov7670_scl(ov7670_scl),
        .ov7670_sda(ov7670_sda)
    );

    button_detector U_button_detector_2 (
        .clk(clk),
        .reset(reset),
        .in_button(btn_chr),
        .rising_edge(obtn_chr)
        //.falling_edge(clk),
        //.both_edge(clk)
    );

    button_detector U_button_detector_3 (
        .clk(clk),
        .reset(reset),
        .in_button(btn_red),
        .rising_edge(obtn_red)
        //.falling_edge(clk),
        //.both_edge(clk)
    );

    ImgROM U_ImgROM (
        .addr(vga_rAddr),
        .data(Rom_Data)
    );

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk),
        .reset  (reset),
        .pclk   (vga_pclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(vga_x_pixel),
        .y_pixel(vga_y_pixel),
        .DE     (vga_DE)
    );

    OV7670_MemController U_OV7670_MemController (
        .clk        (ov7670_pclk),
        .reset      (reset),
        // ov7670 side
        .href       (ov7670_href),
        .vsync      (ov7670_vsync),
        .ov7670_data(ov7670_data),
        // memory side
        .we         (ov7670_we),
        .wAddr      (ov7670_wAddr),
        .wData      (ov7670_wData)
    );

    Frame_2s_Stop U_Frame_2s_Stop (
        .vga_pclk(vga_pclk),
        .reset(reset),
        .y_pixel(vga_y_pixel),
        .f2s_en(f2s_en_out),
        .f2s_val_out(f2s_val_out),
        .led_f2s(led_f2s)
    );

    frame_buffer U_frame_buffer (
        // write side
        .wclk (ov7670_pclk),
        .we   (ov7670_we & ~f2s_val_out),
        .wAddr(ov7670_wAddr),
        .wData(ov7670_wData),
        // read side
        .rclk (vga_pclk),
        .oe   (vga_den),
        .rAddr(vga_rAddr),
        .rData(vga_rData)
    );

    VGA_MemController U_VGA_MemController (
        .vga_pclk   (vga_pclk),
        .reset      (reset),
        .btn_red    (obtn_red),
        .btn_rf     (rf_val),
        .btn_chr    (obtn_chr),
        .f2s_val_out(f2s_val_out),
        .sw_r       (sw_r),
        .sw_g       (sw_g),
        .sw_b       (sw_b),
        // VGA side
        .DE         (vga_DE),
        .x_pixel    (vga_x_pixel),
        .y_pixel    (vga_y_pixel),
        // frame buffer side
        .den        (vga_den),
        .rAddr      (vga_rAddr),
        .rData      (vga_rData),
        .Rom_Data   (Rom_Data),
        // uart side
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        // export side 
        .r_port     (vga_r),
        .g_port     (vga_g),
        .b_port     (vga_b),
        .led_red    (led_red),
        .led_green  (led_green),
        .led_strike (led_strike),
        .led_ball   (led_ball),
        .f2s_en_out (f2s_en_out),
        .Strike     (Strike),
        .Ball       (Ball),
        .ball_pos_1 (ball_pos_1),
        .ball_pos_2 (ball_pos_2),
        .ball_pos_3 (ball_pos_3),
        .ball_pos_4 (ball_pos_4),
        .ball_pos_5 (ball_pos_5),
        .ball_pos_6 (ball_pos_6),
        .ball_pos_7 (ball_pos_7),
        .ball_pos_8 (ball_pos_8),
        .ball_pos_9 (ball_pos_9)
    );

    GrayScaleFilter U_GRAY (
        .i_r(vga_r),
        .i_g(vga_g),
        .i_b(vga_b),
        .o_r(gray_r),
        .o_g(gray_g),
        .o_b(gray_b)
    );

    mux2x1 U_MUX (
        .sel     (sw_gray),
        .vga_rgb ({vga_r, vga_g, vga_b}),
        .gray_rgb({gray_r, gray_g, gray_b}),
        .rgb     ({r_port, g_port, b_port})
    );

    TOP_uart_ctrl U_TOP_uart_ctrl (
        .clk    (clk),
        .reset  (reset),
        .Strike (Strike),
        .Ball   (Ball),
        .tx     (tx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx     (rx)
    );

    NRF24_TOP_RX U_NRF24_TOP_RX (
        .clk      (clk),
        .rst      (reset),
        .rf_val   (rf_val),
        .nrf_sclk (nrf_sclk),
        .nrf_mosi (nrf_mosi),
        .nrf_miso (nrf_miso),
        .nrf_csn  (nrf_csn),
        .nrf_ce   (nrf_ce),
        .nrf_irq_n(nrf_irq_n)
    );

endmodule


module GrayScaleFilter (
    input  logic [3:0] i_r,
    input  logic [3:0] i_g,
    input  logic [3:0] i_b,
    output logic [3:0] o_r,
    output logic [3:0] o_g,
    output logic [3:0] o_b
);

    logic [11:0] gray;

    assign gray = 77 * i_r + 154 * i_g + 25 * i_b;
    assign {o_r, o_g, o_b} = {gray[11:8], gray[11:8], gray[11:8]};

endmodule


module mux2x1 (
    input  logic        sel,
    input  logic [11:0] vga_rgb,
    input  logic [11:0] gray_rgb,
    output logic [11:0] rgb
);

    always_comb begin
        case (sel)
            1'b0: rgb = vga_rgb;
            1'b1: rgb = gray_rgb;
        endcase
    end

endmodule


module button_detector (
    input  logic clk,
    input  logic reset,
    input  logic in_button,
    output logic rising_edge,
    output logic falling_edge,
    output logic both_edge
);
    logic clk_1khz;
    logic debounce;
    logic [7:0] w_shift_reg;
    logic [$clog2(100_000)-1:0] div_counter;

    // clk_div_1khz
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_counter <= 0;
            clk_1khz    <= 1'b0;
        end else begin
            if (div_counter == 100_000) begin
                div_counter <= 0;
                clk_1khz    <= 1'b1;
            end else begin
                div_counter <= div_counter + 1;
                clk_1khz    <= 1'b0;
            end
        end
    end

    shift_register U_SHIFT_REG (
        .clk(clk_1khz),
        .reset(reset),
        .in_data(in_button),
        .out_data(w_shift_reg)
    );

    assign debounce   = &w_shift_reg;
    assign out_button = debounce;

    logic [1:0] edge_reg;

    logic [2:0] cnt;
    logic rising_flag;

    wire rising_edge_reg = edge_reg[0] & ~edge_reg[1];

    // glitch 제거
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            edge_reg <= 0;
            cnt <= 0;
            rising_flag <= 0;
        end else begin
            edge_reg[0] <= debounce;
            edge_reg[1] <= edge_reg[0];
            if (rising_edge_reg) begin
                rising_flag <= 1;
            end
            if (rising_flag) begin
                if (cnt == 3) begin
                    cnt <= 0;
                    rising_edge <= 0;
                    rising_flag <= 0;
                end else begin
                    cnt <= cnt + 1;
                    rising_edge <= 1;
                end
            end
        end
    end

    assign falling_edge = ~edge_reg[0] & edge_reg[1];
    assign both_edge = rising_edge | falling_edge;

endmodule



module shift_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       in_data,
    output logic [7:0] out_data
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            out_data <= 0;
        end else begin
            out_data <= {in_data, out_data[7:1]};
            // out_data <= {out_data[6:0], in_data};
        end
    end

endmodule
