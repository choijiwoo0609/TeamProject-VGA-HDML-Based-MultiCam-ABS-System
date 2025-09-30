`timescale 1ns / 1ps

module SPI_Master_RF #(
    parameter DIV = 50   // 분주값: 100MHz / (2*DIV) = SCLK
)(
    input  wire       clk,      // 시스템 클럭 (예: 100 MHz)
    input  wire       rstn,
    input  wire       start,    // 1바이트 전송 요청
    input  wire [7:0] tx_byte,
    output reg  [7:0] rx_byte,
    output reg        done,     // 1클럭 펄스
    output reg        busy,
    input  wire       hold_csn, // 1이면 CSN 유지, 0이면 바이트마다 CSN 토글
    // SPI 핀
    output wire       sclk,
    output reg        mosi,
    input  wire       miso,
    output wire       csn
);

    // Divider
    reg [$clog2(DIV)-1:0] div_cnt;
    reg tick;

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            div_cnt <= 0;
            tick    <= 1'b0;
        end else if (busy) begin
            if (div_cnt == DIV - 1) begin
                div_cnt <= 0;
                tick    <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1;
                tick    <= 1'b0;
            end
        end else begin
            div_cnt <= 0;
            tick    <= 1'b0;
        end
    end

    // FSM 상태 정의
    localparam [2:0]
        IDLE          = 3'd0,
        DATA          = 3'd1,
        ASSERT        = 3'd2,
        SHIFT         = 3'd3,
        SHIFT_LASTFALL= 3'd4,
        DONE_ST       = 3'd5;

    reg [2:0] state;

    reg [7:0] sh_tx, sh_rx;
    reg [2:0] bit_cnt;
    reg sclk_q, csn_q;

    assign sclk = sclk_q;
    assign csn  = csn_q;

    // FSM
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state   <= IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            sclk_q  <= 1'b0; // idle low
            csn_q   <= 1'b1; // idle high
            mosi    <= 1'b0;
            rx_byte <= 8'h00;
            sh_tx   <= 8'h00;
            sh_rx   <= 8'h00;
            bit_cnt <= 3'd7;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    sclk_q <= 1'b0;
                    busy   <= 1'b0;

                    if (start) begin
                        bit_cnt <= 3'd7;
                        csn_q   <= 1'b0;  // CSN low
                        busy    <= 1'b1;
                        state   <= DATA;
                    end else if (!hold_csn) begin
                        csn_q <= 1'b1;    // CSN high
                    end
                end

                DATA: begin
                    sh_tx <= tx_byte;
                    state <= ASSERT;
                end

                ASSERT: begin
                    mosi  <= sh_tx[bit_cnt];
                    state <= SHIFT;
                end

                SHIFT: if (tick) begin
                    sclk_q <= ~sclk_q;
                    if (sclk_q == 1'b0) begin
                        // Rising edge: 샘플링
                        sh_rx[bit_cnt] <= miso;
                        if (bit_cnt == 0) begin
                            rx_byte <= {sh_rx[7:1], miso};
                            state   <= SHIFT_LASTFALL;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end else begin
                        // Falling edge: MOSI 갱신
                        mosi <= sh_tx[bit_cnt];
                    end
                end

                SHIFT_LASTFALL: if (tick) begin
                    sclk_q <= 1'b0;
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
