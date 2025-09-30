`timescale 1ns / 1ps

module VGA_Camera_Display (
    input  logic        clk,
    input  logic        reset,
    // ov7670 side
    output logic        ov7670_xclk,
    input  logic        ov7670_pclk,
    input  logic        ov7670_href,
    input  logic        ov7670_vsync,
    input  logic [ 7:0] ov7670_data,
    // external port
    output logic        h_sync,
    output logic        v_sync,
    output logic [ 3:0] r_port,
    output logic [ 3:0] g_port,
    output logic [ 3:0] b_port,
    output logic [15:0] led_count,
    output logic        ov7670_scl,
    output logic        ov7670_sda,
    output logic        nrf_sclk,
    output logic        nrf_mosi,
    input  logic        nrf_miso,
    output logic        nrf_csn,
    output logic        nrf_ce,
    input  logic        nrf_irq_n
);

    logic        ov7670_we;
    logic [16:0] ov7670_wAddr;
    logic [15:0] ov7670_wData;

    logic        vga_pclk;
    logic [ 9:0] vga_x_pixel;
    logic [ 9:0] vga_y_pixel;
    logic        vga_DE;

    logic        vga_den;
    logic        cap_val;
    logic [16:0] vga_rAddr;
    logic [15:0] vga_rData;

    logic [15:0] Rom_Data;

    logic [ 9:0] h_out;
    logic [ 6:0] s_out;
    logic [ 6:0] v_out;

    assign ov7670_xclk = vga_pclk;

    TOP_sccb_ctrl U_SCCB_CTRL (
        .clk       (clk),
        .reset     (reset),
        .ov7670_scl(ov7670_scl),
        .ov7670_sda(ov7670_sda)
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
        .href       (ov7670_href),
        .vsync      (ov7670_vsync),
        .ov7670_data(ov7670_data),
        .we         (ov7670_we),
        .wAddr      (ov7670_wAddr),
        .wData      (ov7670_wData)
    );

    Frame_2s_Stop U_Frame_2s_Stop (
        .vga_pclk   (vga_pclk),
        .reset      (reset),
        .y_pixel    (vga_y_pixel),
        .f2s_en     (cap_val),
        .f2s_val_out(f2s_val_out),
        .led_f2s    (led_f2s)
    );

    frame_buffer U_FrameBuffer (
        .wclk (ov7670_pclk),
        .we   (ov7670_we & ~f2s_val_out),
        .wAddr(ov7670_wAddr),
        .wData(ov7670_wData),
        .rclk (vga_pclk),
        .oe   (vga_den),
        .rAddr(vga_rAddr),
        .rData(vga_rData)
    );

    ImgROM U_ImgROM (
        .addr(vga_rAddr),
        .data(Rom_Data)
    );

    VGA_MemController U_VGA_MemController (
        .clk      (vga_pclk),
        .reset    (reset),
        .DE       (vga_DE),
        .x_pixel  (vga_x_pixel),
        .y_pixel  (vga_y_pixel),
        .den      (vga_den),
        .cap_val  (cap_val),
        .led_count(led_count),
        .rAddr    (vga_rAddr),
        .rData    (vga_rData),
        .Rom_Data (Rom_Data),
        .h_out    (h_out),
        .s_out    (s_out),
        .v_out    (v_out),
        .r_port   (r_port),
        .g_port   (g_port),
        .b_port   (b_port)
    );

    RGB_to_HSV U_RGB_to_HSV (
        .rData(vga_rData),
        .h_out(h_out),
        .s_out(s_out),
        .v_out(v_out)
    );

    NRF24_TOP_TX U_NRF24_TOP_TX (
        .clk      (clk),
        .rst      (reset),
        .cap_val  (cap_val),
        .nrf_sclk (nrf_sclk),
        .nrf_mosi (nrf_mosi),
        .nrf_miso (nrf_miso),
        .nrf_csn  (nrf_csn),
        .nrf_ce   (nrf_ce),
        .nrf_irq_n(nrf_irq_n)
    );
endmodule
