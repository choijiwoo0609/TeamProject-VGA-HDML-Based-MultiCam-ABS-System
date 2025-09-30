//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
//Date        : Fri Sep 26 12:13:33 2025
//Host        : DESKTOP-7CFQ9ND running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (clk_in1_0,
    hdmi_out_clk_n,
    hdmi_out_clk_p,
    hdmi_out_data_n,
    hdmi_out_data_p,
    hdmi_out_hpd,
    href_0,
    led0_0,  
    nrf_ce_0,
    nrf_csn_0,
    nrf_irq_n_0,
    nrf_miso_0,
    nrf_mosi_0,
    nrf_sclk_0,
    ov7670_data_0,
    ov7670_scl_0,
    ov7670_sda_0,
    ov_pclk_0,
    resetn_0,
    vsync_0,
    xclk);
  input clk_in1_0;
  output hdmi_out_clk_n;
  output hdmi_out_clk_p;
  output [2:0]hdmi_out_data_n;
  output [2:0]hdmi_out_data_p;
  output [0:0]hdmi_out_hpd;
  input href_0;
  output led0_0;
  output nrf_ce_0;
  output nrf_csn_0;
  input nrf_irq_n_0;
  input nrf_miso_0;
  output nrf_mosi_0;
  output nrf_sclk_0;
  input [7:0]ov7670_data_0;
  output ov7670_scl_0;
  inout ov7670_sda_0;
  input ov_pclk_0;
  input resetn_0;
  input vsync_0;
  output [0:0]xclk;

  wire clk_in1_0;
  wire hdmi_out_clk_n;
  wire hdmi_out_clk_p;
  wire [2:0]hdmi_out_data_n;
  wire [2:0]hdmi_out_data_p;
  wire [0:0]hdmi_out_hpd;
  wire href_0;
  wire led0_0;
  wire nrf_ce_0;
  wire nrf_csn_0;
  wire nrf_irq_n_0;
  wire nrf_miso_0;
  wire nrf_mosi_0;
  wire nrf_sclk_0;
  wire [7:0]ov7670_data_0;
  wire ov7670_scl_0;
  wire ov7670_sda_0;
  wire ov_pclk_0;
  wire resetn_0;
  wire vsync_0;
  wire [0:0]xclk;

  design_1 design_1_i
       (.clk_in1_0(clk_in1_0),
        .hdmi_out_clk_n(hdmi_out_clk_n),
        .hdmi_out_clk_p(hdmi_out_clk_p),
        .hdmi_out_data_n(hdmi_out_data_n),
        .hdmi_out_data_p(hdmi_out_data_p),
        .hdmi_out_hpd(hdmi_out_hpd),
        .href_0(href_0),
        .led0_0(led0_0),
        .nrf_ce_0(nrf_ce_0),
        .nrf_csn_0(nrf_csn_0),
        .nrf_irq_n_0(nrf_irq_n_0),
        .nrf_miso_0(nrf_miso_0),
        .nrf_mosi_0(nrf_mosi_0),
        .nrf_sclk_0(nrf_sclk_0),
        .ov7670_data_0(ov7670_data_0),
        .ov7670_scl_0(ov7670_scl_0),
        .ov7670_sda_0(ov7670_sda_0),
        .ov_pclk_0(ov_pclk_0),
        .resetn_0(resetn_0),
        .vsync_0(vsync_0),
        .xclk(xclk));
endmodule
