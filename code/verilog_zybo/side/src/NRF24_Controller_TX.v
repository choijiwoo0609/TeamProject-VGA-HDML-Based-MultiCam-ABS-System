`timescale 1ns / 1ps

module NRF24_Controller_TX #(
    parameter SYS_CLK_HZ = 100_000_000,
    parameter CE_PULSE_US = 15,
    parameter RF_CHANNEL = 8'h4c,
    parameter [39:0] NRF_TX_ADDR = 40'hE7E7E7E7E7,
    parameter [39:0] NRF_RX_ADDR = 40'hE7E7E7E7E7
) (
    input wire clk,
    input wire rstn,

    // SPI master
    output reg        spi_start,
    output reg  [7:0] spi_tx,
    input  wire [7:0] spi_rx,
    input  wire       spi_done,
    output reg        spi_hold_csn,

    // nRF24L01 핀
    output reg  CE,
    input  wire IRQ_n,

    // 사용자 인터페이스
    input  wire       tx_req,
    input  wire [7:0] tx_data,
    output reg        tx_done,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        cap_done
);

  // CE 펄스 길이 카운트
  localparam CE_PULSE_CYCLES = (SYS_CLK_HZ / 1_000_000) * CE_PULSE_US;
  reg [$clog2(CE_PULSE_CYCLES)-1:0] ce_cnt;

  // Power up 대기
  localparam PWRUP_WAIT_CYCLES = (SYS_CLK_HZ / 1000) * 2;
  reg [$clog2(PWRUP_WAIT_CYCLES)-1:0] pwr_cnt;

  // IRQ 동기화기
  reg irq_n_s1, irq_n_s2;
  reg irq_n_sync;

  always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
      irq_n_s1   <= 1'b1;
      irq_n_s2   <= 1'b1;
      irq_n_sync <= 1'b1;
    end else begin
      irq_n_s1   <= IRQ_n;
      irq_n_s2   <= irq_n_s1;
      irq_n_sync <= irq_n_s2;
    end
  end

  // FSM 상태 인코딩
  localparam [6:0]
        INIT_CONFIG        = 0,
        INIT_CONFIG2       = 1,
        INIT_PWRUP_WAIT    = 2,
        INIT_ENAA1         = 3,
        INIT_ENAA2         = 4,
        INIT_ENAA_WAIT     = 5,
        INIT_ERX1          = 6,
        INIT_ERX2          = 7,
        INIT_ERX_WAIT      = 8,
        INIT_SETUP_AW1     = 9,
        INIT_SETUP_AW2     = 10,
        INIT_SETUP_AW_WAIT = 11,
        INIT_RF_CH         = 12,
        INIT_RF_CH2        = 13,
        INIT_RF_CH_WAIT    = 14,
        INIT_RF_SETUP      = 15,
        INIT_RF_SETUP2     = 16,
        INIT_RF_SETUP_WAIT = 17,
        INIT_STATUS1       = 18,
        INIT_STATUS2       = 19,
        INIT_STATUS_WAIT   = 20,
        INIT_TX_ADDR       = 21,
        INIT_TX_ADDR_B1    = 22,
        INIT_TX_ADDR_B2    = 23,
        INIT_TX_ADDR_B3    = 24,
        INIT_TX_ADDR_B4    = 25,
        INIT_TX_ADDR_B5    = 26,
        INIT_TX_ADDR_WAIT  = 27,
        INIT_RX_ADDR       = 28,
        INIT_RX_ADDR_B1    = 29,
        INIT_RX_ADDR_B2    = 30,
        INIT_RX_ADDR_B3    = 31,
        INIT_RX_ADDR_B4    = 32,
        INIT_RX_ADDR_B5    = 33,
        INIT_RX_ADDR_WAIT  = 34,
        FLUSH_TX           = 35,
        FLUSH_TX_WAIT      = 36,
        FLUSH_RX           = 37,
        FLUSH_RX_WAIT      = 38,
        IDLE               = 39,
        TX_CMD             = 40,
        TX_BYTE            = 41,
        TX_CE              = 42,
        TX_WAIT_IRQ        = 43,
        TX_CONFIG          = 44,
        TX_STATUS1         = 45,
        TX_STATUS2         = 46,
        TX_STATUS3         = 47,
        RX_CMD             = 48,
        RX_BYTE            = 49,
        RX_DONE            = 50,
        RX_CLEAR_IRQ1      = 51,
        RX_CLEAR_IRQ2      = 52,
        RX_CLEAR_IRQ_WAIT  = 53,
        HANDLE_MAX_RT      = 54,
        HANDLE_RX_DR       = 55,
        HANDLE_TX_DS       = 56,
        HANDLE_WAIT        = 57,
        HANDLE_TX_FLUSH    = 58,
        HANDLE_TX_FLUSH_WAIT = 59;

  reg [6:0] state;
  reg [7:0] rx_buf;
  reg cnt_flag;

  // CE 출력 제어
  always @(*) begin
    case (state)
      TX_CMD:  CE = 1'b1;
      TX_BYTE: CE = 1'b1;
      TX_CE:   CE = 1'b1;
      RX_CMD:  CE = 1'b1;
      RX_BYTE: CE = 1'b1;
      RX_DONE: CE = 1'b1;
      default: CE = 1'b0;
    endcase
  end

  // FSM
  always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
      state        <= INIT_CONFIG;
      ce_cnt       <= 0;
      rx_buf       <= 8'h00;
      rx_data      <= 8'h00;
      spi_start    <= 1'b0;
      spi_tx       <= 8'h00;
      spi_hold_csn <= 1'b0;
      tx_done      <= 1'b0;
      rx_valid     <= 1'b0;
      cnt_flag     <= 1'b0;
      cap_done     <= 0;
    end else begin
      spi_start <= 1'b0;
      tx_done   <= 1'b0;
      rx_valid  <= 1'b0;

      case (state)
        // ---------------- INIT ----------------
        INIT_CONFIG: begin
          spi_tx       <= 8'h20;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_CONFIG2;
        end
        INIT_CONFIG2:
        if (spi_done) begin
          spi_tx    <= 8'h0A;
          spi_start <= 1'b1;
          state     <= INIT_PWRUP_WAIT;
          pwr_cnt   <= 0;
        end
        INIT_PWRUP_WAIT: begin
          if (spi_done) spi_hold_csn <= 1'b0;
          if (pwr_cnt == PWRUP_WAIT_CYCLES - 1) begin
            state   <= INIT_ENAA1;
            pwr_cnt <= 0;
          end else pwr_cnt <= pwr_cnt + 1;
        end
        INIT_ENAA1: begin
          spi_tx       <= 8'h21;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_ENAA2;
        end
        INIT_ENAA2:
        if (spi_done) begin
          spi_tx    <= 8'h01;
          spi_start <= 1'b1;
          state     <= INIT_ENAA_WAIT;
        end
        INIT_ENAA_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= INIT_ERX1;
        end
        INIT_ERX1: begin
          spi_tx       <= 8'h22;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_ERX2;
        end
        INIT_ERX2:
        if (spi_done) begin
          spi_tx    <= 8'h01;
          spi_start <= 1'b1;
          state     <= INIT_ERX_WAIT;
        end
        INIT_ERX_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= INIT_SETUP_AW1;
        end
        INIT_SETUP_AW1: begin
          spi_tx       <= 8'h23;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_SETUP_AW2;
        end
        INIT_SETUP_AW2:
        if (spi_done) begin
          spi_tx    <= 8'h03;
          spi_start <= 1'b1;
          state     <= INIT_SETUP_AW_WAIT;
        end
        INIT_SETUP_AW_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= INIT_RF_CH;
        end
        INIT_RF_CH: begin
          spi_tx       <= 8'h25;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_RF_CH2;
        end
        INIT_RF_CH2:
        if (spi_done) begin
          spi_tx    <= RF_CHANNEL[7:0];
          spi_start <= 1'b1;
          state     <= INIT_RF_CH_WAIT;
        end
        INIT_RF_CH_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state        <= INIT_RF_SETUP;
        end
        INIT_RF_SETUP: begin
          spi_tx       <= 8'h26;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_RF_SETUP2;
        end
        INIT_RF_SETUP2:
        if (spi_done) begin
          spi_tx    <= 8'h06;
          spi_start <= 1'b1;
          state     <= INIT_RF_SETUP_WAIT;
        end
        INIT_RF_SETUP_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state        <= INIT_STATUS1;
        end
        INIT_STATUS1: begin
          spi_tx       <= 8'h27;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_STATUS2;
        end
        INIT_STATUS2:
        if (spi_done) begin
          spi_tx    <= 8'h70;
          spi_start <= 1'b1;
          state     <= INIT_STATUS_WAIT;
        end
        INIT_STATUS_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state        <= INIT_TX_ADDR;
        end

        // ---------------- TX_ADDR ----------------
        INIT_TX_ADDR: begin
          spi_tx       <= 8'h20 | 8'h10;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_TX_ADDR_B1;
        end
        INIT_TX_ADDR_B1:
        if (spi_done) begin
          spi_tx    <= NRF_TX_ADDR[7:0];
          spi_start <= 1'b1;
          state     <= INIT_TX_ADDR_B2;
        end
        INIT_TX_ADDR_B2:
        if (spi_done) begin
          spi_tx    <= NRF_TX_ADDR[15:8];
          spi_start <= 1'b1;
          state     <= INIT_TX_ADDR_B3;
        end
        INIT_TX_ADDR_B3:
        if (spi_done) begin
          spi_tx    <= NRF_TX_ADDR[23:16];
          spi_start <= 1'b1;
          state     <= INIT_TX_ADDR_B4;
        end
        INIT_TX_ADDR_B4:
        if (spi_done) begin
          spi_tx    <= NRF_TX_ADDR[31:24];
          spi_start <= 1'b1;
          state     <= INIT_TX_ADDR_B5;
        end
        INIT_TX_ADDR_B5:
        if (spi_done) begin
          spi_tx    <= NRF_TX_ADDR[39:32];
          spi_start <= 1'b1;
          state     <= INIT_TX_ADDR_WAIT;
        end
        INIT_TX_ADDR_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= INIT_RX_ADDR;
        end

        // ---------------- RX_ADDR ----------------
        INIT_RX_ADDR: begin
          spi_tx       <= 8'h20 | 8'h0A;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= INIT_RX_ADDR_B1;
        end
        INIT_RX_ADDR_B1:
        if (spi_done) begin
          spi_tx    <= NRF_RX_ADDR[7:0];
          spi_start <= 1'b1;
          state     <= INIT_RX_ADDR_B2;
        end
        INIT_RX_ADDR_B2:
        if (spi_done) begin
          spi_tx    <= NRF_RX_ADDR[15:8];
          spi_start <= 1'b1;
          state     <= INIT_RX_ADDR_B3;
        end
        INIT_RX_ADDR_B3:
        if (spi_done) begin
          spi_tx    <= NRF_RX_ADDR[23:16];
          spi_start <= 1'b1;
          state     <= INIT_RX_ADDR_B4;
        end
        INIT_RX_ADDR_B4:
        if (spi_done) begin
          spi_tx    <= NRF_RX_ADDR[31:24];
          spi_start <= 1'b1;
          state     <= INIT_RX_ADDR_B5;
        end
        INIT_RX_ADDR_B5:
        if (spi_done) begin
          spi_tx    <= NRF_RX_ADDR[39:32];
          spi_start <= 1'b1;
          state     <= INIT_RX_ADDR_WAIT;
        end
        INIT_RX_ADDR_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= FLUSH_TX;
        end

        // ---------------- FLUSH ----------------
        FLUSH_TX: begin
          spi_tx       <= 8'hE1;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= FLUSH_TX_WAIT;
        end
        FLUSH_TX_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= FLUSH_RX;
        end
        FLUSH_RX: begin
          spi_tx       <= 8'hE2;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= FLUSH_RX_WAIT;
        end
        FLUSH_RX_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state        <= IDLE;
        end

        // ---------------- IDLE ----------------
        IDLE: begin
          cap_done <= 1;
          if (tx_req) begin
            spi_tx       <= 8'hA0;
            spi_start    <= 1'b1;
            spi_hold_csn <= 1'b1;
            state        <= TX_CMD;
          end else if (!irq_n_sync) begin
            spi_tx       <= 8'h61;
            spi_start    <= 1'b1;
            spi_hold_csn <= 1'b1;
            state        <= RX_CMD;
          end else state <= IDLE;
        end

        // ---------------- TX ----------------
        TX_CMD:
        if (spi_done) begin
          cap_done  <= 0;
          spi_tx    <= tx_data;
          spi_start <= 1'b1;
          state     <= TX_BYTE;
        end
        TX_BYTE:
        if (spi_done) begin
          ce_cnt       <= 0;
          spi_hold_csn <= 1'b0;
          state        <= TX_CE;
        end
        TX_CE:
        if (ce_cnt == CE_PULSE_CYCLES - 1) state <= TX_WAIT_IRQ;
        else ce_cnt <= ce_cnt + 1;
        TX_WAIT_IRQ:
        if (!irq_n_sync) begin
          spi_hold_csn <= 1'b0;
          state        <= TX_CONFIG;
        end
        TX_CONFIG: begin
          spi_tx       <= 8'hFF;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= TX_STATUS1;
        end
        TX_STATUS1:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          rx_buf <= spi_rx;
          state <= TX_STATUS2;
        end
        TX_STATUS2: begin
          rx_data  <= rx_buf;
          rx_valid <= 1'b1;
          state    <= TX_STATUS3;
        end
        TX_STATUS3: begin
          if (rx_data[4]) begin
            spi_tx       <= 8'h27;
            spi_start    <= 1'b1;
            spi_hold_csn <= 1'b1;
            state        <= HANDLE_MAX_RT;
          end else if (rx_data[5]) begin
            spi_tx       <= 8'h27;
            spi_start    <= 1'b1;
            spi_hold_csn <= 1'b1;
            state        <= HANDLE_TX_DS;
          end else if (rx_data[6]) begin
            spi_tx       <= 8'h27;
            spi_start    <= 1'b1;
            spi_hold_csn <= 1'b1;
            state        <= HANDLE_RX_DR;
          end else state <= IDLE;
        end

        // ---------------- HANDLE ----------------
        HANDLE_MAX_RT:
        if (spi_done) begin
          spi_tx    <= 8'h10;
          spi_start <= 1'b1;
          state     <= HANDLE_WAIT;
        end
        HANDLE_TX_DS:
        if (spi_done) begin
          spi_tx    <= 8'h20;
          spi_start <= 1'b1;
          state     <= HANDLE_WAIT;
        end
        HANDLE_RX_DR:
        if (spi_done) begin
          spi_tx    <= 8'h40;
          spi_start <= 1'b1;
          state     <= HANDLE_TX_FLUSH_WAIT;
        end
        HANDLE_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state        <= HANDLE_TX_FLUSH;
        end
        HANDLE_TX_FLUSH: begin
          spi_tx       <= 8'hE1;
          spi_start    <= 1'b1;
          spi_hold_csn <= 1'b1;
          state        <= HANDLE_TX_FLUSH_WAIT;
        end
        HANDLE_TX_FLUSH_WAIT:
        if (spi_done) begin
          spi_hold_csn <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
