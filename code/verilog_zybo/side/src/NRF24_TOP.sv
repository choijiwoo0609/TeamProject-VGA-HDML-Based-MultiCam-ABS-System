`timescale 1ns / 1ps

//=============================================================================
// TOP 모듈
// - cap_val (비동기 입력)에 대한 동기화기 추가
//=============================================================================
module NRF24_TOP_TX (
    input  logic clk,
    input  logic rst,
    input  logic cap_val,   // ★★★ 비동기 입력
    // nRF24L01 핀
    output logic nrf_sclk,
    output logic nrf_mosi,
    input  logic nrf_miso,
    output logic nrf_csn,
    output logic nrf_ce,
    input  logic nrf_irq_n  // ★★★ 비동기 입력
);

    // SPI master
    logic spi_start, spi_done, spi_hold_csn, spi_busy;
    logic [7:0] spi_tx, spi_rx;

    SPI_Master_RF #(
        .DIV(50)
    ) SPI (
        .clk     (clk),
        .rst     (rst),
        .start   (spi_start),
        .tx_byte (spi_tx),
        .rx_byte (spi_rx),
        .done    (spi_done),
        .busy    (),
        .hold_csn(spi_hold_csn),
        .sclk    (nrf_sclk),
        .mosi    (nrf_mosi),
        .miso    (nrf_miso),
        .csn     (nrf_csn)
    );

    // Controller
    logic tx_req, tx_done;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic rx_valid;
    logic       cap_done; // ★★★ 오타 수정 (CTRL_TX의 cap_done 포트 연결)

    NRF24_Controller_TX CTRL_TX (
        .clk         (clk),
        .rst         (rst),
        .spi_start   (spi_start),
        .spi_tx      (spi_tx),
        .spi_rx      (spi_rx),
        .spi_done    (spi_done),
        .spi_hold_csn(spi_hold_csn),
        .CE          (nrf_ce),
        .IRQ_n       (nrf_irq_n),     // 비동기 신호 전달
        .tx_req      (tx_req),
        .tx_data     (tx_data),
        .tx_done     (tx_done),
        .rx_data     (rx_data),
        .rx_valid    (rx_valid),
        .cap_done    (cap_done)       // ★★★ 포트 연결
    );

    // ★★★ 수정: cap_val (비동기 스위치 입력) 동기화기 (2-FF) ★★★
    logic cap_val_s1, cap_val_s2;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cap_val_s1 <= 1'b0;
            cap_val_s2 <= 1'b0;
        end else begin
            cap_val_s1 <= cap_val;
            cap_val_s2 <= cap_val_s1;
        end
    end
    // ★★★ 수정 끝 ★★★


    // 스위치 변화 감지 → TX 요청
    logic cap_val_q, cap_val_changed;
    logic [10:0] cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cap_val_q <= 0;
            cnt <= 0;
            cap_val_changed <= 0;
        end else begin
            // ★★★ 수정: 원본 cap_val 대신 동기화된 cap_val_s2 사용 ★★★
            if (!cap_val_q & cap_val_s2) begin
                cap_val_q <= cap_val_s2;
                cap_val_changed <= 1;
            end else if (cap_val_q & cap_done) begin
                if (cnt > 2000) begin
                    cnt <= 0;
                    cap_val_q <= cap_val_s2; // ★★★ 수정: cap_val_s2 사용
                    cap_val_changed <= 1;
                end else begin
                    cnt <= cnt + 1;
                end
            end else begin
                cap_val_changed <= 0;
            end
        end
    end

    // wire cap_val_changed = (cap_val_q != cap_val); // <-- 주석 처리

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_req  <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            if (cap_val_changed) begin
                tx_req <= 1'b1;
                tx_data <= {
                    7'b0, cap_val_q
                };  // cap_val_q는 이미 동기화된 값
            end else begin
                tx_req <= 1'b0;
            end
        end
    end

endmodule
