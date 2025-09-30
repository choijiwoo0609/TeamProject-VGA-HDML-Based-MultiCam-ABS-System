`timescale 1ns / 1ps
module NRF24_TOP_RX (
    input logic clk,
    input logic rst,
    output logic [7:0] rf_val,

    // nRF24L01 핀
    output logic nrf_sclk,
    output logic nrf_mosi,
    input  logic nrf_miso,
    output logic nrf_csn,
    output logic nrf_ce,
    input  logic nrf_irq_n
);

    // SPI master
    logic spi_start, spi_done, spi_hold_csn, spi_busy;
    logic [7:0] spi_tx, spi_rx;

    SPI_Master_RF #(
        .DIV(50)
    ) SPI (
        .clk(clk),
        .rst(rst),
        .start(spi_start),
        .tx_byte(spi_tx),
        .rx_byte(spi_rx),
        .done(spi_done),
        .busy(),
        .hold_csn(spi_hold_csn),
        .sclk(nrf_sclk),
        .mosi(nrf_mosi),
        .miso(nrf_miso),
        .csn(nrf_csn)
    );

    // Controller
    logic tx_req, tx_done;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       rx_valid;

    NRF24_Controller_RX CTRL (
        .clk(clk),
        .rst(rst),
        .spi_start(spi_start),
        .spi_tx(spi_tx),
        .spi_rx(spi_rx),
        .spi_done(spi_done),
        .spi_hold_csn(spi_hold_csn),
        .CE(nrf_ce),
        .IRQ_n(nrf_irq_n),
        //.tx_req(tx_req),
        .tx_data(tx_data),
        .tx_done(tx_done),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    assign rf_val = rx_data;

endmodule
