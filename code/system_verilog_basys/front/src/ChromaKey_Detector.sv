`timescale 1ns / 1ps


module ChromaKey_Detector (
    input  logic       vga_pclk,
    input  logic       reset,
    input  logic       en,
    input  logic       den,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [9:0] h_out,
    input  logic [6:0] s_out,
    input  logic [6:0] v_out,
    input  logic [3:0] reg_r,
    input  logic [3:0] reg_g,
    input  logic [3:0] reg_b,
    output logic [9:0] chr_min_x,
    output logic [9:0] chr_max_x
);

    logic [9:0] reg_min_x, reg_max_x;
    logic [2:0] chr_cnt;
    logic cnt_flag, x_flag;

    assign chr_min_x = reg_min_x;
    assign chr_max_x = reg_max_x;

    always_ff @(posedge vga_pclk, posedge reset) begin
        if (reset) begin
            reg_min_x <= 0;
            reg_max_x <= 0;
            chr_cnt   <= 0;
            cnt_flag  <= 0;
            x_flag    <= 0;
        end else begin
            if (en) begin
                if (den) begin
                    if (y_pixel == 240) begin
                        if (((reg_g + 1) > reg_r + 2) && ((reg_g + 1) >= reg_b + 2) && 
                              ((reg_g + 1) >= 1)) begin
                            if (chr_cnt == 5) begin
                                chr_cnt  <= 0;
                                cnt_flag <= 1;
                            end else begin
                                chr_cnt <= chr_cnt + 1;
                            end
                            if (cnt_flag) begin
                                if (!x_flag) begin
                                    reg_min_x <= x_pixel;
                                    x_flag <= 1;
                                end else begin
                                    reg_max_x <= x_pixel;
                                end
                            end
                        end else begin
                                chr_cnt <= 0;
                                cnt_flag <= 0;
                        end
                    end else begin
                        cnt_flag <= 0;
                        x_flag   <= 0;
                    end
                end
            end
        end
    end

endmodule
