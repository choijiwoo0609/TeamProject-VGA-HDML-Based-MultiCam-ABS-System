`timescale 1ns / 1ps

module NRF24_TOP_TX (
    input  wire clk,
    input  wire rstn,
    input  wire cap_val,   // 비동기 입력
    // nRF24L01 핀
    output wire nrf_sclk,
    output wire nrf_mosi,
    input  wire nrf_miso,
    output wire nrf_csn,
    output wire nrf_ce,
    input  wire nrf_irq_n  // 비동기 입력
);

    // SPI master
    wire       spi_start, spi_done, spi_hold_csn;
    wire [7:0] spi_tx, spi_rx;

    SPI_Master_RF #(
        .DIV(50)
    ) SPI (
        .clk     (clk),
        .rstn     (rstn),
        .start   (spi_start),
        .tx_byte (spi_tx),
        .rx_byte (spi_rx),
        .done    (spi_done),
        .busy    (),              // 사용하지 않음
        .hold_csn(spi_hold_csn),
        .sclk    (nrf_sclk),
        .mosi    (nrf_mosi),
        .miso    (nrf_miso),
        .csn     (nrf_csn)
    );

    // Controller
    reg        tx_req;
    reg  [7:0] tx_data;
    wire       tx_done;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       cap_done;

    NRF24_Controller_TX CTRL_TX (
        .clk         (clk),
        .rstn         (rstn),
        .spi_start   (spi_start),
        .spi_tx      (spi_tx),
        .spi_rx      (spi_rx),
        .spi_done    (spi_done),
        .spi_hold_csn(spi_hold_csn),
        .CE          (nrf_ce),
        .IRQ_n       (nrf_irq_n),
        .tx_req      (tx_req),
        .tx_data     (tx_data),
        .tx_done     (tx_done),
        .rx_data     (rx_data),
        .rx_valid    (rx_valid),
        .cap_done    (cap_done)
    );

    // cap_val 동기화기 (2-FF)
    reg cap_val_s1, cap_val_s2;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            cap_val_s1 <= 1'b0;
            cap_val_s2 <= 1'b0;
        end else begin
            cap_val_s1 <= cap_val;
            cap_val_s2 <= cap_val_s1;
        end
    end

    // 스위치 변화 감지 → TX 요청
    reg cap_val_q, cap_val_changed;
    reg [10:0] cnt;

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            cap_val_q      <= 1'b0;
            cnt            <= 11'd0;
            cap_val_changed<= 1'b0;
        end else begin
            if (!cap_val_q & cap_val_s2) begin
                cap_val_q      <= cap_val_s2;
                cap_val_changed<= 1'b1;
            end else if (cap_val_q & cap_done) begin
                if (cnt > 2000) begin
                    cnt            <= 0;
                    cap_val_q      <= cap_val_s2;
                    cap_val_changed<= 1'b1;
                end else begin
                    cnt <= cnt + 1;
                end
            end else begin
                cap_val_changed<= 1'b0;
            end
        end
    end

    // TX 요청 및 데이터 생성
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            tx_req  <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            if (cap_val_changed) begin
                tx_req  <= 1'b1;
                tx_data <= {7'b0, cap_val_q}; // 동기화된 값 사용
            end else begin
                tx_req <= 1'b0;
            end
        end
    end

endmodule
