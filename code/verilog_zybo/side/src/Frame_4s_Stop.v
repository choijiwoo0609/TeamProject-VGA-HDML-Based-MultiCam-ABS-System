`timescale 1ns / 1ps


module Frame_4s_Stop (
    input  wire       pclk,
    input  wire       rstn,
    input  wire [9:0] y_pixel,
    input  wire       f2s_en,
    output wire       f2s_val_out
    //output reg       led_f2s
);
    localparam IDLE = 0;
    localparam ONE = 1;

    reg [7:0] cnt, next_cnt;
    reg state, state_next;
    reg flag, next_flag;
    reg f2s_val, next_f2s_val;
    wire yen;

    assign yen = y_pixel < 480;
    //assign led_f2s = f2s_val;
    assign f2s_val_out = f2s_val;

    always @(posedge pclk or negedge rstn) begin
        if (~rstn) begin
            state <= IDLE;
            cnt <= 0;
            flag <= 0;
            f2s_val <= 0;
        end else begin
            state <= state_next;
            cnt <= next_cnt;
            flag <= next_flag;
            f2s_val <= next_f2s_val;
        end
    end

    always @(*) begin
        state_next = state;
        next_cnt = cnt;
        next_flag = flag;
        next_f2s_val = f2s_val;
        case (state)
            IDLE: begin
                if (f2s_en) begin
                    next_flag = 1;
                end
                if (flag) begin
                    if (!yen) begin
                        if (cnt == 230 - 1) begin
                            next_cnt = 0;
                            next_f2s_val = 0;
                            next_flag = 0;
                        end else begin
                            state_next = ONE;
                        end
                    end
                end
            end
            ONE: begin
                if (yen) begin
                    next_f2s_val = 1;
                    next_cnt = cnt + 1;
                    state_next = IDLE;
                end
            end
        endcase
    end

endmodule
