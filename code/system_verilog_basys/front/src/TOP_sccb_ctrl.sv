`timescale 1ns / 1ps

module TOP_sccb_ctrl (
    input  logic clk,
    input  logic reset,
    output logic ov7670_scl,
    inout  logic ov7670_sda
);

    logic tick;
    logic sccb_start;
    logic [7:0] reg_addr;
    logic [7:0] write_data;
    logic sccb_done;
    logic [15:0] rom_data;
    logic [ 7:0] rom_addr;

    i2c_tick U_i2c_tick (
        .clk  (clk),
        .reset(reset),
        .tick (tick)
    );

    i2c_sccb_ctrl U_i2c_sccb_ctrl (
        .clk(tick),
        .reset(reset),
        .start(sccb_start),
        .reg_addr(reg_addr),
        .data(write_data),
        .done(sccb_done),//
        .rom_data(rom_data),//
        .rom_addr(rom_addr)//
    );

    i2c_sccb U_i2c_sccb(
        .clk(tick),
        .reset(reset),
        .start(sccb_start),  
        .indata({8'h42, reg_addr[7:0],write_data[7:0]}),
        .scl(ov7670_scl),//
        .sda(ov7670_sda),//
        .done(sccb_done)     //    
    );

    i2c_rom U_i2c_rom (
        .clk (tick),
        .addr(rom_addr),//
        .dout(rom_data)//
    );

endmodule