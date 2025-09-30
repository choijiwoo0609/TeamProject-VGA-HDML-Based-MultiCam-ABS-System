`timescale 1ns / 1ps

module i2c_sccb (
    input               clk,         // 400kHz tick input
    input               rstn,
    input               start,       // 트랜잭션 시작
    input      [23:0]   indata,      // {slave_addr[7:0], reg_addr[7:0], data[7:0]}
    output              scl,
    inout               sda,
    output reg          done         // 완료 표시
);

    // FSM States (enum 대체)
    parameter [3:0] IDLE              = 4'd0;
    parameter [3:0] START             = 4'd1;
    parameter [3:0] SETUP             = 4'd2;
    parameter [3:0] SCL_HIGH          = 4'd3;
    parameter [3:0] SCL_LOW           = 4'd4;
    parameter [3:0] WAIT_ACK_SETUP    = 4'd5;
    parameter [3:0] WAIT_ACK_SAMPLE   = 4'd6;
    parameter [3:0] NEXT_BYTE         = 4'd7; // 원본 코드에는 사용되지 않았지만 포함
    parameter [3:0] STOP1             = 4'd8;
    parameter [3:0] STOP2             = 4'd9;
    parameter [3:0] DONE_STATE        = 4'd10; // DONE은 예약어일 수 있으므로 이름 변경

    reg [3:0] state;
    reg [23:0] shifter;     // 전송할 3바이트 데이터
    reg [2:0] bit_cnt;      // 0~7 비트 전송 인덱스
    reg [1:0] byte_cnt;     // 0: slave_addr, 1: reg_addr, 2: data

    reg scl_reg;
    reg sda_reg;
    reg sda_oe;

    assign scl = scl_reg;
    assign sda = sda_oe ? 1'bz : sda_reg; // 0이면 FPGA가 sda라인에 출력, 1이면 슬레이브가 제어

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state    <= IDLE;
            shifter  <= 24'b0;
            bit_cnt  <= 3'd7;
            byte_cnt <= 2'd0;
            scl_reg  <= 1;
            sda_reg  <= 1;
            sda_oe   <= 1;
            done     <= 0;
        end else begin
            case (state)
                IDLE: begin
                    scl_reg  <= 1;
                    sda_reg  <= 1;
                    sda_oe   <= 1;
                    done     <= 0;
                    if (start) begin
                        shifter  <= indata;
                        bit_cnt  <= 3'd7;
                        byte_cnt <= 2'd0;
                        sda_reg  <= 0;    // SDA 하강 Start 1상태
                        sda_oe   <= 0;    // FGPA의 출력
                        state    <= START;
                    end
                end

                START: begin
                    scl_reg <= 0;        // SCL = LOW Start_2 state
                    state   <= SETUP;
                end

                // sda 먼저 내리고 scl 이후에 내리고 초기 설정 끝
                SETUP: begin
                    // 정확한 MSB-first 방식으로 인덱싱
                    sda_reg <= shifter[23 - (byte_cnt * 8 + (7 - bit_cnt))]; // 8개의 bit로 하나씩
                    sda_oe  <= 0;
                    scl_reg <= 0;
                    state   <= SCL_HIGH;
                end

                SCL_HIGH: begin
                    scl_reg <= 1;        // 슬레이브 샘플링 타이밍 SCL이 HIGH일 때 scl값은 high
                    state   <= SCL_LOW;
                end

                SCL_LOW: begin // 1 byte 전송할 수 있게 하는 과정
                    scl_reg <= 0;
                    if (bit_cnt == 0) begin
                        bit_cnt <= 3'd7;
                        sda_oe  <= 1;    // SDA 입력으로 전환
                        state   <= WAIT_ACK_SETUP;
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                        state   <= SETUP; // 다음 비트 전송
                    end
                end

                WAIT_ACK_SETUP: begin
                    scl_reg <= 1;        // SCL High => slave로 ack 신호 전달
                    state   <= WAIT_ACK_SAMPLE;
                end

                WAIT_ACK_SAMPLE: begin
                    // ACK == 0 (Low) -> sda == 0
                    scl_reg <= 0;
                    sda_oe  <= 0;        // 다시 출력 모드로 전환
                    if (sda == 1'b0) begin
                        if (byte_cnt == 2) begin
                            state <= STOP1;
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                            state    <= SETUP;
                        end
                    end else begin
                        // NACK: 즉시 STOP
                        state <= STOP1;
                    end
                end

                STOP1: begin
                    sda_reg <= 0;
                    sda_oe  <= 0;
                    scl_reg <= 1;
                    state   <= STOP2;
                end

                STOP2: begin
                    sda_reg <= 1;        // SDA ↑ while SCL ↑ → STOP 조건
                    state   <= DONE_STATE;
                end

                DONE_STATE: begin
                    done  <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE; // 안전을 위해 default 상태 추가

            endcase
        end
    end
endmodule