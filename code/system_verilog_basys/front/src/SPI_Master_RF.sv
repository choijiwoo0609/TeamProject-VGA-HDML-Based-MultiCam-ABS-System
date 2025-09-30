// -----------------------------------------------------------------------------
// SPI Master (Byte 단위 전송, Mode 0: CPOL=0, CPHA=0)
// - start 펄스 들어오면 tx_byte를 보냄
// - 동시에 MISO로 1바이트 수신
// - done 펄스로 완료 알림
// - hold_csn=1이면 여러 바이트 전송할 때 CSN 유지
// -----------------------------------------------------------------------------
module SPI_Master_RF #(
    parameter int DIV = 50  // 분주값: 100MHz / (2*DIV) = SCLK
) (
    input logic clk,  // 시스템 클럭 (예: 100 MHz)
    input logic rst,

    input  logic       start,    // 1바이트 전송 요청
    input  logic [7:0] tx_byte,
    output logic [7:0] rx_byte,
    output logic       done,     // 1클럭 펄스
    output logic       busy,

    input  logic hold_csn,    // 1이면 CSN 유지, 0이면 바이트마다 CSN 토글

    // SPI 핀
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic csn
);

    // Divider
    logic [$clog2(DIV)-1:0] div_cnt;
    logic tick;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end else if (busy) begin
            if (div_cnt == DIV - 1) begin
                div_cnt <= '0;
                tick    <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1;
                tick    <= 1'b0;
            end
        end else begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end
    end

    // FSM
    typedef enum {
        IDLE,
        DATA,
        ASSERT,
        SHIFT,
        SHIFT_LASTFALL,
        DONE_ST,
        CSN
    } state_e;
    state_e state;

    logic [7:0] sh_tx, sh_rx;
    logic [2:0] bit_cnt;
    logic sclk_q, csn_q;

    assign sclk = sclk_q;
    assign csn  = csn_q;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            sclk_q  <= 1'b0; // idle low
            csn_q   <= 1'b1;
            mosi    <= 1'b0;
            rx_byte <= 8'h00;
            sh_tx   <= 8'h00;
            sh_rx   <= 8'h00;
            bit_cnt <= 3'd7;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    //if (!hold_csn) csn_q <= 1'b1;  // CSN 해제
                    //// else csn_q <= 1'b0;
                    //sclk_q <= 1'b0;
                    //busy   <= 1'b0;
                    //if (start) begin
                    //    bit_cnt <= 3'd7;
                    //    csn_q   <= 1'b0;  // CSN low
                    //    busy    <= 1'b1;
                    //    state   <= DATA;
                    //end

                    // else csn_q <= 1'b0;
                    sclk_q <= 1'b0;
                    busy   <= 1'b0;
                    if (start) begin
                        bit_cnt <= 3'd7;
                        csn_q   <= 1'b0;  // CSN low
                        busy    <= 1'b1;
                        state   <= DATA;
                    end else begin
                        if (!hold_csn) csn_q <= 1'b1;  // CSN 해제    
                    end
                end

                DATA: begin
                    sh_tx <= tx_byte;
                    state <= ASSERT;
                end

                ASSERT: begin
                    // 첫 MOSI 세팅
                    mosi  <= sh_tx[bit_cnt];
                    state <= SHIFT;
                end

                SHIFT:
                if (tick) begin
                    sclk_q <= ~sclk_q;
                    if (sclk_q == 1'b0) begin
                        // rising edge: MISO 샘플
                        sh_rx[bit_cnt] <= miso;
                        if (bit_cnt == 0) begin
                            rx_byte <= {sh_rx[7:1], miso};
                            state   <= SHIFT_LASTFALL;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end else begin
                        // falling edge: MOSI 갱신
                        mosi <= sh_tx[bit_cnt];
                    end
                end

                SHIFT_LASTFALL:
                if (tick) begin
                    sclk_q <= 1'b0;  // 마지막 falling edge
                    state  <= DONE_ST;
                    done   <= 1'b1;
                end

                DONE_ST: begin
                    sclk_q <= 1'b0;
                    busy   <= 1'b0;
                    mosi   <= 1'b0;
                    state  <= IDLE;
                end
            endcase
        end
    end

endmodule
