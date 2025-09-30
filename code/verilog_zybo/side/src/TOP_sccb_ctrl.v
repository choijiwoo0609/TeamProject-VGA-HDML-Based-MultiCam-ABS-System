`timescale 1ns / 1ps

module TOP_sccb_ctrl (
    input   clk,
    input   rstn,
    output  ov7670_scl,
    inout   ov7670_sda
);

    wire tick;
    wire sccb_start;
    wire [7:0] reg_addr;
    wire [7:0] write_data;
    wire sccb_done;
    wire [15:0] rom_data;
    wire [ 7:0] rom_addr;

    i2c_tick U_i2c_tick (
        .clk  (clk),
        .rstn(rstn),
        .tick (tick)
    );

    i2c_sccb_ctrl U_i2c_sccb_ctrl (
        .clk(tick),
        .rstn(rstn),
        .start(sccb_start),
        .reg_addr(reg_addr),
        .data(write_data),
        .done(sccb_done),//
        .rom_data(rom_data),//
        .rom_addr(rom_addr)//
    );

    i2c_sccb U_i2c_sccb(
        .clk(tick),
        .rstn(rstn),
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