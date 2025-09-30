`timescale 1ns / 1ps

// control unit

module i2c_sccb_ctrl (
    input logic clk,
    input logic reset,

    output logic        start,
    output logic [ 7:0] reg_addr,
    output logic [ 7:0] data,
    input  logic        done,
    input  logic [15:0] rom_data,
    output logic [ 7:0] rom_addr

);

    typedef enum {
        IDLE,
        START,
        WAIT_DONE,
        WAIT,
        DONE
    } state_e;
    state_e state;

    logic [6:0] wait_count;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            start      <= 1'b0;
            reg_addr   <= 0;
            data       <= 0;
            rom_addr   <= 0;
            wait_count <= 0;
        end else begin

            case (state)
                IDLE: begin  // 바로 Start로 이동
                    state <= START;
                end
                START: begin  // rom에서 가져온 신호 전달
                    state <= WAIT_DONE;
                    start    <= 1'b1;  // i2c_sccb모듈에게 데이터 전송 시작하는 신호 전달
                    reg_addr <= rom_data[15:8]; // 카메라 레지스터 주소값
                    data     <= rom_data[7:0]; // 카메라 레지스터에 쓸 값 전달
                end
                WAIT_DONE: begin  // done 신호 대기 
                    start <= 1'b0;
                    if (done) begin // i2c_sccb모듈에게 done 신호가 들어올때까지 기달림 - 명령어 하나 읽으면 done 신호 나옴
                        if (rom_data == 16'hFFFF) begin
                            rom_addr <= 0;
                            state <= DONE;
                        end else begin
                            rom_addr <= rom_addr + 1;
                            state    <= WAIT;
                        end
                    end
                end
                WAIT: begin // 몇 클럭정도 대기 후 다음 전송으로 이동
                    if (wait_count == 100) begin
                        state    <= START;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1;
                    end
                end
                DONE: begin

                end
            endcase
        end
    end
endmodule
