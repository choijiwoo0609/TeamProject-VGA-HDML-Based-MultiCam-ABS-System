`timescale 1ns / 1ps

// control unit

module i2c_sccb_ctrl (
    input               clk,
    input               rstn,

    output reg          start,
    output reg [ 7:0]   reg_addr,
    output reg [ 7:0]   data,
    input               done,
    input      [15:0]   rom_data,
    output reg [ 7:0]   rom_addr
);

    // FSM States (enum 대체)
    parameter [2:0] IDLE        = 3'd0;
    parameter [2:0] START       = 3'd1;
    parameter [2:0] WAIT_DONE   = 3'd2;
    parameter [2:0] WAIT        = 3'd3;
    parameter [2:0] DONE        = 3'd4;

    reg [2:0] state;
    reg [6:0] wait_count;

    // always_ff를 always로 변경하고, 민감도 목록(sensitivity list)을 표준 형식으로 수정
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state      <= IDLE;
            start      <= 1'b0;
            reg_addr   <= 0;
            data       <= 0;
            rom_addr   <= 0;
            wait_count <= 0;
        end else begin
            case (state)
                IDLE: begin // 바로 Start로 이동
                    state <= START;
                end
                
                START: begin // rom에서 가져온 신호 전달
                    state    <= WAIT_DONE;
                    start    <= 1'b1; // i2c_sccb모듈에게 데이터 전송 시작하는 신호 전달
                    reg_addr <= rom_data[15:8]; // 카메라 레지스터 주소값
                    data     <= rom_data[7:0]; // 카메라 레지스터에 쓸 값 전달
                end

                WAIT_DONE: begin // done 신호 대기
                    start <= 1'b0;
                    if (done) begin // i2c_sccb모듈에게 done 신호가 들어올때까지 기달림
                        if (rom_data == 16'hFFFF) begin
                            rom_addr <= 0;
                            state    <= DONE;
                        end else begin
                            rom_addr <= rom_addr + 1;
                            state    <= WAIT;
                        end
                    end
                end
                
                WAIT: begin // 몇 클럭정도 대기 후 다음 전송으로 이동
                    if (wait_count == 100) begin
                        state      <= START;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1;
                    end
                end
                
                DONE: begin
                    // 모든 전송 완료 후 IDLE 상태로 돌아가려면 여기에 'state <= IDLE;' 추가 가능
                end
                
                default: state <= IDLE;

            endcase
        end
    end
endmodule