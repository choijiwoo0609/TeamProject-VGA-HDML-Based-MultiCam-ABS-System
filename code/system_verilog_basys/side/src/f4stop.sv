`timescale 1ns / 1ps


module Frame_4s_Stop (
    input  logic       vga_pclk,
    input  logic       reset,
    input  logic [9:0] y_pixel,
    input  logic       f2s_en,
    output logic       f2s_val_out,
    output logic       led_f2s
);
    localparam IDLE = 0;
    localparam ONE = 1;

    logic [8:0] cnt, next_cnt;
    logic state, state_next;
    logic flag, next_flag;
    logic f2s_val, next_f2s_val;
    logic yen;

    assign yen = y_pixel < 480;
    assign led_f2s = f2s_val;
    assign f2s_val_out = f2s_val;

    always_ff @(posedge vga_pclk, posedge reset) begin
        if (reset) begin
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

    always_comb begin
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
