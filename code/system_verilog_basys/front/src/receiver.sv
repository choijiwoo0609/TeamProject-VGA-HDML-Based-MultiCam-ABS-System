`timescale 1ns / 1ps

module receiver (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       br_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    typedef enum {
        IDLE,
        START,
        DATA,
        STOP
    } rx_state_e;

    rx_state_e rx_state, rx_next_state;

    logic [7:0] rx_data_reg, rx_data_next;
    logic rx_done_reg, rx_done_next;
    logic [4:0] tick_cnt_reg, tick_cnt_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            rx_state <= IDLE;
            rx_data_reg <= 0;
            rx_done_reg <= 0;
            tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
        end else begin
            rx_state <= rx_next_state;
            rx_data_reg <= rx_data_next;
            rx_done_reg <= rx_done_next;
            tick_cnt_reg <= tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
        end
    end

    always_comb begin
        rx_next_state = rx_state;
        rx_data_next  = rx_data_reg;
        rx_done_next  = rx_done_reg;
        tick_cnt_next = tick_cnt_reg;
        bit_cnt_next  = bit_cnt_reg;

        case (rx_state)
            IDLE: begin
                rx_done_next = 0;
                if (rx == 0) begin
                    rx_next_state = START;
                    tick_cnt_next = 0;
                    bit_cnt_next  = 0;
                end
            end

            START: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 7) begin
                        rx_next_state = DATA;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = 0;
                        if (bit_cnt_reg == 8) begin
                            rx_next_state = STOP;
                            bit_cnt_next  = 0;
                        end else begin
                            rx_data_next = {rx, rx_data_reg[7:1]};
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 23) begin
                        rx_next_state = IDLE;
                        rx_done_next  = 1;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
