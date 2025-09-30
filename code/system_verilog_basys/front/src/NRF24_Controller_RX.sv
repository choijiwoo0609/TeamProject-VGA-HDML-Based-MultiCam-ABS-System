// -----------------------------------------------------------------------------
// nRF24L01 Controller (Full Version)
// - SPI Master 사용 (1-byte 인터페이스)
// - Reset 후 CONFIG, RF_CH, RF_SETUP, TX_ADDR, RX_ADDR_P0 초기화
// - TX 시: FLUSH_TX 포함
// - RX 시: FLUSH_RX 포함
// -----------------------------------------------------------------------------
module NRF24_Controller_RX #(
    parameter int SYS_CLK_HZ = 100_000_000,
    parameter int CE_PULSE_US = 15,
    parameter int RF_CHANNEL = 8'h4c,  // Channel 76
    parameter logic [39:0] NRF_TX_ADDR = 40'hE7E7E7E7E7,  // 5바이트 주소
    parameter logic [39:0] NRF_RX_ADDR = 40'hE7E7E7E7E7  // 5바이트 주소
) (
    input logic clk,
    input logic rst,

    // SPI master 연결
    output logic       spi_start,
    output logic [7:0] spi_tx,
    input  logic [7:0] spi_rx,
    input  logic       spi_done,
    output logic       spi_hold_csn,

    // nRF24L01 핀
    output logic CE,
    input  logic IRQ_n,

    // 사용자 인터페이스
    input  logic       tx_req,
    input  logic [7:0] tx_data,
    output logic       tx_done,
    output logic [7:0] rx_data,
    output logic       rx_valid
);

    // CE 펄스 길이
    localparam int CE_PULSE_CYCLES = (SYS_CLK_HZ / 1_000_000) * CE_PULSE_US;
    logic [$clog2(CE_PULSE_CYCLES)-1:0] ce_cnt;

    localparam int PWRUP_WAIT_CYCLES = (SYS_CLK_HZ / 1000) * 2;  // 2 ms
    logic [$clog2(PWRUP_WAIT_CYCLES)-1:0] pwr_cnt;

    // FSM 상태
    typedef enum logic [6:0] {
        INIT_CONFIG,
        INIT_CONFIG2,

        INIT_PWRUP_WAIT,

        INIT_ENAA1,
        INIT_ENAA2,
        INIT_ENAA_WAIT,

        INIT_ERX1,
        INIT_ERX2,
        INIT_ERX_WAIT,

        INIT_SETUP_AW1,
        INIT_SETUP_AW2,
        INIT_SETUP_AW_WAIT,

        INIT_RF_CH,
        INIT_RF_CH2,
        INIT_RF_CH_WAIT,

        INIT_RF_SETUP,
        INIT_RF_SETUP2,
        INIT_RF_SETUP_WAIT,

        INIT_STATUS1,
        INIT_STATUS2,
        INIT_STATUS_WAIT,

        INIT_TX_ADDR,
        INIT_TX_ADDR_B1,
        INIT_TX_ADDR_B2,
        INIT_TX_ADDR_B3,
        INIT_TX_ADDR_B4,
        INIT_TX_ADDR_B5,
        INIT_TX_ADDR_WAIT,

        INIT_RX_ADDR,
        INIT_RX_ADDR_B1,
        INIT_RX_ADDR_B2,
        INIT_RX_ADDR_B3,
        INIT_RX_ADDR_B4,
        INIT_RX_ADDR_B5,
        INIT_RX_ADDR_WAIT,

        INIT_RX_PW1,
        INIT_RX_PW2,
        INIT_RX_PW_WAIT,

        FLUSH_TX,
        FLUSH_TX_WAIT,
        FLUSH_RX,
        FLUSH_RX_WAIT,

        IDLE,
        TX_CMD,
        TX_BYTE,
        TX_CE,
        TX_WAIT_IRQ,
        TX_CONFIG,
        TX_STATUS1,
        TX_STATUS2,
        TX_STATUS3,
        RX_CMD,
        RX_BYTE,
        RX_DONE,
        RX_STATUS0,
        RX_STATUS1,
        RX_STATUS2,

        HANDLE_MAX_RT,
        HANDLE_RX_DR,
        HANDLE_TX_DS,
        HANDLE_WAIT
    } state_e;

    state_e state;

    logic [7:0] rx_buf;
    logic cnt_flag;

        // ★★★ 수정: IRQ_n (비동기 인터럽트) 동기화기 (3-FF) ★★★
    logic irq_n_s1, irq_n_s2;
    logic irq_n_sync; // FSM에서 사용할 동기화된 IRQ 신호

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            irq_n_s1   <= 1'b1;
            irq_n_s2   <= 1'b1;
            irq_n_sync <= 1'b1;
        end else begin
            irq_n_s1   <= IRQ_n;    // 1단
            irq_n_s2   <= irq_n_s1; // 2단
            irq_n_sync <= irq_n_s2; // 3단 (FSM에서 사용)
        end
    end

    // CE 출력
    always_comb begin
        CE = (state==TX_CE) ? 1'b1 :
         (state inside {RX_STATUS1, RX_STATUS2, RX_STATUS0, IDLE, RX_CMD,RX_BYTE,RX_DONE}) ? 1'b1 :
         1'b0;
    end

    // FSM
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= INIT_CONFIG;
            ce_cnt       <= '0;
            rx_buf       <= 8'h00;
            rx_data      <= 8'h00;
            spi_start    <= 1'b0;
            spi_tx       <= 8'h00;
            spi_hold_csn <= 1'b0;
            tx_done      <= 1'b0;
            rx_valid     <= 1'b0;
            cnt_flag     <= 1'b0;
        end else begin
            // 기본값
            spi_start <= 1'b0;
            tx_done   <= 1'b0;
            rx_valid  <= 1'b0;

            case (state)
                // ---------------- INIT ----------------
                INIT_CONFIG: begin
                    spi_tx       <= 8'h20;  // W_REGISTER CONFIG
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_CONFIG2;
                end
                INIT_CONFIG2:
                if (spi_done) begin
                    spi_tx    <= 8'h0b;  // PWR_UP=1, CRC=1, PRIM_RX=1
                    spi_start <= 1'b1;
                    state     <= INIT_PWRUP_WAIT;
                    pwr_cnt   <= '0;
                end
                INIT_PWRUP_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;  // CONFIG 거래 종료
                    end
                    if (pwr_cnt == PWRUP_WAIT_CYCLES - 1) begin
                        state   <= INIT_ENAA1;
                        pwr_cnt <= '0;

                    end else begin
                        pwr_cnt <= pwr_cnt + 1;
                    end
                end
                INIT_ENAA1: begin
                    spi_tx <= 8'h21;  //  W_REGISTER | EN_AA_REG
                    spi_start <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state <= INIT_ENAA2;
                end
                INIT_ENAA2: begin
                    if (spi_done) begin
                        spi_tx <= 8'h01; // ENAA_P0, P1 (auto ack, data pipe 0, 1 enable)
                        spi_start <= 1'b1;
                        state <= INIT_ENAA_WAIT;
                    end
                end
                INIT_ENAA_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= INIT_ERX1;
                    end
                end
                INIT_ERX1: begin
                    //if (spi_done) begin
                    spi_tx <= 8'h22;  // W_REGISTER | EN_RXADDR_REG
                    spi_start <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state <= INIT_ERX2;
                    //end
                end
                INIT_ERX2: begin
                    if (spi_done) begin
                        spi_tx <= 8'h01;  // ERX_P0, P1 (data pipe 0, 1 enable)
                        spi_start <= 1'b1;
                        state <= INIT_ERX_WAIT;
                    end
                end
                INIT_ERX_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= INIT_SETUP_AW1;
                    end
                end
                INIT_SETUP_AW1: begin
                    //if (spi_done) begin
                    spi_tx <= 8'h23;  // W_REGISTER | SETUP_AW_REG
                    spi_start <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state <= INIT_SETUP_AW2;
                    //end
                end
                INIT_SETUP_AW2: begin
                    if (spi_done) begin
                        spi_tx <= 8'h03;  // RX/TX Address Field 5 Byte
                        spi_start <= 1'b1;
                        state <= INIT_SETUP_AW_WAIT;
                    end
                end
                INIT_SETUP_AW_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= INIT_RF_CH;
                    end
                end
                INIT_RF_CH: begin
                    //if (spi_done) begin
                    spi_tx       <= 8'h25;  // W_REGISTER RF_CH
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_RF_CH2;
                    //end
                end
                INIT_RF_CH2: begin
                    if (spi_done) begin
                        spi_tx    <= RF_CHANNEL[7:0];  // Channe 76
                        spi_start <= 1'b1;
                        state     <= INIT_RF_CH_WAIT;
                    end
                end
                INIT_RF_CH_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= INIT_RF_SETUP;
                    end
                end
                INIT_RF_SETUP: begin
                    //if (spi_done) begin
                    spi_tx       <= 8'h26;  // W_REGISTER RF_SETUP
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_RF_SETUP2;
                    //end
                end
                INIT_RF_SETUP2: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h06;  // 1Mbps, 0dBm
                        spi_start <= 1'b1;
                        state     <= INIT_RF_SETUP_WAIT;
                    end
                end
                INIT_RF_SETUP_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= INIT_STATUS1;
                    end
                end
                INIT_STATUS1: begin
                    //if (spi_done) begin
                    spi_tx       <= 8'h27;  //  W_REGISTER | STATUS
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_STATUS2;
                    //end
                end
                INIT_STATUS2: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h70;  //  Clear RX_DR, TX_DS, MAX_RT
                        spi_start <= 1'b1;
                        state     <= INIT_STATUS_WAIT;
                    end
                end
                INIT_STATUS_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= INIT_TX_ADDR;
                    end
                end
                // TX_ADDR 쓰기
                INIT_TX_ADDR: begin
                    //if (spi_done) begin
                    spi_tx       <= 8'h20 | 8'h10;  // W_REGISTER TX_ADDR
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_TX_ADDR_B1;
                    //end
                end
                INIT_TX_ADDR_B1: begin
                    if (spi_done) begin
                        spi_tx <= NRF_TX_ADDR[7:0];
                        spi_start <= 1'b1;
                        state <= INIT_TX_ADDR_B2;
                    end
                end
                INIT_TX_ADDR_B2: begin
                    if (spi_done) begin
                        spi_tx <= NRF_TX_ADDR[15:8];
                        spi_start <= 1'b1;
                        state <= INIT_TX_ADDR_B3;
                    end
                end
                INIT_TX_ADDR_B3: begin
                    if (spi_done) begin
                        spi_tx <= NRF_TX_ADDR[23:16];
                        spi_start <= 1'b1;
                        state <= INIT_TX_ADDR_B4;
                    end
                end
                INIT_TX_ADDR_B4: begin
                    if (spi_done) begin
                        spi_tx <= NRF_TX_ADDR[31:24];
                        spi_start <= 1'b1;
                        state <= INIT_TX_ADDR_B5;
                    end
                end
                INIT_TX_ADDR_B5: begin
                    if (spi_done) begin
                        spi_tx <= NRF_TX_ADDR[39:32];
                        spi_start <= 1'b1;
                        state <= INIT_TX_ADDR_WAIT;
                    end
                end
                INIT_TX_ADDR_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= INIT_RX_ADDR;
                    end
                end

                INIT_RX_ADDR: begin
                    //if (spi_done) begin
                    spi_tx       <= 8'h20 | 8'h0A;  // W_REGISTER RX_ADDR_P1
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= INIT_RX_ADDR_B1;
                    //end
                end
                INIT_RX_ADDR_B1: begin
                    if (spi_done) begin
                        spi_tx <= NRF_RX_ADDR[7:0];
                        spi_start <= 1'b1;
                        state <= INIT_RX_ADDR_B2;
                    end
                end
                INIT_RX_ADDR_B2: begin
                    if (spi_done) begin
                        spi_tx <= NRF_RX_ADDR[15:8];
                        spi_start <= 1'b1;
                        state <= INIT_RX_ADDR_B3;
                    end
                end
                INIT_RX_ADDR_B3: begin
                    if (spi_done) begin
                        spi_tx <= NRF_RX_ADDR[23:16];
                        spi_start <= 1'b1;
                        state <= INIT_RX_ADDR_B4;
                    end
                end
                INIT_RX_ADDR_B4: begin
                    if (spi_done) begin
                        spi_tx <= NRF_RX_ADDR[31:24];
                        spi_start <= 1'b1;
                        state <= INIT_RX_ADDR_B5;
                    end
                end
                INIT_RX_ADDR_B5: begin
                    if (spi_done) begin
                        spi_tx <= NRF_RX_ADDR[39:32];
                        spi_start <= 1'b1;
                        state <= INIT_RX_ADDR_WAIT;
                    end
                end
                INIT_RX_ADDR_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= INIT_RX_PW1;
                    end
                end

                INIT_RX_PW1: begin
                    spi_tx <= 8'h31;
                    spi_hold_csn <= 1'b1;
                    spi_start <= 1'b1;
                    state <= INIT_RX_PW2;

                end
                INIT_RX_PW2: begin
                    if (spi_done) begin
                        spi_tx <= 8'h01;
                        spi_start <= 1'b1;
                        state <= INIT_RX_PW_WAIT;
                    end
                end
                INIT_RX_PW_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= FLUSH_TX;
                    end
                end

                FLUSH_TX: begin
                    //if (spi_done) begin
                    spi_tx <= 8'hE1;
                    spi_start <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state <= FLUSH_TX_WAIT;
                    //end
                end
                FLUSH_TX_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state <= FLUSH_RX;
                    end
                end
                FLUSH_RX: begin
                    //if (spi_done) begin
                    spi_tx <= 8'hE2;
                    spi_start <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state <= FLUSH_RX_WAIT;
                    //end
                end
                FLUSH_RX_WAIT: begin  // INIT_DONE
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= IDLE;
                    end
                end
                // ---------------- IDLE ----------------
                IDLE: begin
                    if (!irq_n_sync) begin
                        spi_tx       <= 8'h61;  // R_RX_PAYLOAD
                        spi_start    <= 1'b1;
                        spi_hold_csn <= 1'b1;
                        state        <= RX_CMD;
                    end else begin
                        state <= IDLE;
                    end
                end
                // ---------------- RX ----------------
                RX_CMD: begin
                    if (spi_done) begin
                        spi_tx    <= 8'hFF;  // dummy
                        spi_start <= 1'b1;
                        state     <= RX_BYTE;
                    end
                end
                RX_BYTE: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        rx_buf <= spi_rx;
                        state <= RX_DONE;
                    end
                end
                RX_DONE: begin
                    rx_data      <= rx_buf;
                    rx_valid     <= 1'b1;
                    state        <= RX_STATUS0;
                end

                RX_STATUS0: begin
                    spi_tx       <= 8'h27;
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= RX_STATUS1;
                end

                RX_STATUS1: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h40;
                        spi_start <= 1'b1;
                        state     <= RX_STATUS2;
                    end
                end

                RX_STATUS2: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= IDLE;
                    end
                end

                // ---------------- TX ----------------
                TX_CMD: begin
                    if (spi_done) begin
                        spi_tx    <= tx_data;
                        spi_start <= 1'b1;
                        state     <= TX_BYTE;
                    end
                end
                TX_BYTE: begin
                    if (spi_done) begin
                        ce_cnt       <= '0;
                        spi_hold_csn <= 1'b0;
                        state        <= TX_CE;
                    end
                end
                TX_CE: begin
                    if (ce_cnt == CE_PULSE_CYCLES - 1) state <= TX_WAIT_IRQ;
                    else ce_cnt <= ce_cnt + 1;
                end
                TX_WAIT_IRQ: begin
                    if (!irq_n_sync) begin
                        spi_hold_csn <= 1'b0;
                        state        <= TX_CONFIG;
                        // state        <= IDLE;
                    end
                end

                TX_CONFIG: begin
                    spi_tx       <= 8'hFF;  // dummy
                    spi_start    <= 1'b1;
                    spi_hold_csn <= 1'b1;
                    state        <= TX_STATUS1;
                end
                TX_STATUS1: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        rx_buf <= spi_rx;
                        state <= TX_STATUS2;
                    end
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
                    end else begin
                        state <= IDLE;
                    end
                end
                HANDLE_MAX_RT: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h10;
                        spi_start <= 1'b1;
                        state     <= HANDLE_WAIT;
                    end
                end
                HANDLE_TX_DS: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h20;
                        spi_start <= 1'b1;
                        state     <= HANDLE_WAIT;
                    end
                end

                HANDLE_RX_DR: begin
                    if (spi_done) begin
                        spi_tx    <= 8'h40;
                        spi_start <= 1'b1;
                        state     <= HANDLE_WAIT;
                    end
                end
                HANDLE_WAIT: begin
                    if (spi_done) begin
                        spi_hold_csn <= 1'b0;
                        state        <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
