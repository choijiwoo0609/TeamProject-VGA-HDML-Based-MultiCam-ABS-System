`timescale 1ns / 1ps

module TOP_uart_ctrl (
    input  logic       clk,
    input  logic       reset,
    input  logic       Strike,
    input  logic       Ball,
    output logic [7:0] rx_data,
    output logic       rx_done,
    input  logic       rx,
    output logic       tx
);
    logic       br_tick;
    logic [7:0] ascii;

    buadrate U_buadrate (
        .clk    (clk),
        .rst    (reset),
        .br_tick(br_tick)
    );

    ascii U_ascii (
        .Strike(Strike),
        .Ball  (Ball),
        .ascii (ascii)
    );

    transmitter U_transmitter (
        .clk     (clk),
        .rst     (reset),
        .br_tick (br_tick),
        .tx_start(Strike | Ball),
        .tx_data (ascii),
        .tx_busy (),
        .tx_done (),
        .tx      (tx)
    );

    receiver U_receiver (
        .clk    (clk),
        .rst    (reset),
        .rx     (rx),
        .br_tick(br_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );
endmodule
