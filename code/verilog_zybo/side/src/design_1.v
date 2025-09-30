//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
//Date        : Fri Sep 26 12:13:33 2025
//Host        : DESKTOP-7CFQ9ND running 64-bit major release  (build 9200)
//Command     : generate_target design_1.bd
//Design      : design_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "design_1,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=design_1,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=18,numReposBlks=18,numNonXlnxBlks=1,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=12,numPkgbdBlks=0,bdsource=USER,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "design_1.hwdef" *) 
module design_1
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
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK_IN1_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK_IN1_0, CLK_DOMAIN design_1_clk_in1_0, FREQ_HZ 125000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.000" *) input clk_in1_0;
  (* X_INTERFACE_INFO = "digilentinc.com:interface:tmds:1.0 hdmi_out CLK_N" *) output hdmi_out_clk_n;
  (* X_INTERFACE_INFO = "digilentinc.com:interface:tmds:1.0 hdmi_out CLK_P" *) output hdmi_out_clk_p;
  (* X_INTERFACE_INFO = "digilentinc.com:interface:tmds:1.0 hdmi_out DATA_N" *) output [2:0]hdmi_out_data_n;
  (* X_INTERFACE_INFO = "digilentinc.com:interface:tmds:1.0 hdmi_out DATA_P" *) output [2:0]hdmi_out_data_p;
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
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESETN_0 RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESETN_0, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input resetn_0;
  input vsync_0;
  output [0:0]xclk;

  wire DelayRegs_0_de_out;
  wire DelayRegs_0_hs_out;
  wire DelayRegs_0_vs_out;
  wire DelayRegs_1_de_out;
  wire DelayRegs_1_hs_out;
  wire DelayRegs_1_vs_out;
  wire Frame_4s_Stop_0_f2s_val_out;
  wire [15:0]Frame_Buffer_0_rData;
  wire HDMI_Decoder_0_DE;
  wire HDMI_Decoder_0_h_sync;
  wire HDMI_Decoder_0_v_sync;
  wire [9:0]HDMI_Decoder_0_x_pixel;
  wire [9:0]HDMI_Decoder_0_y_pixel;
  wire [4:0]HDMI_MemController_0_b_port;
  wire HDMI_MemController_0_cap_val;
  wire HDMI_MemController_0_den;
  wire [5:0]HDMI_MemController_0_g_port;
  wire HDMI_MemController_0_led0;
  wire [16:0]HDMI_MemController_0_rAddr;
  wire [4:0]HDMI_MemController_0_r_port;
  wire [15:0]ImgROM_0_data;
  wire NRF24_TOP_TX_0_nrf_ce;
  wire NRF24_TOP_TX_0_nrf_csn;
  wire NRF24_TOP_TX_0_nrf_mosi;
  wire NRF24_TOP_TX_0_nrf_sclk;
  wire Net;
  wire OV7670_Controller_0_WE;
  wire [16:0]OV7670_Controller_0_wAddr;
  wire [15:0]OV7670_Controller_0_wData;
  wire [9:0]RGB_to_HSV_0_h_out;
  wire [6:0]RGB_to_HSV_0_s_out;
  wire [6:0]RGB_to_HSV_0_v_out;
  wire TOP_sccb_ctrl_0_ov7670_scl;
  wire [7:0]Transformer_565_to_8_0_b_port_8;
  wire [7:0]Transformer_565_to_8_0_g_port_8;
  wire [7:0]Transformer_565_to_8_0_r_port_8;
  wire clk_in1_0_1;
  wire clk_wiz_0_clk_100;
  wire clk_wiz_0_clk_125;
  wire clk_wiz_0_clk_25;
  wire href_0_1;
  wire nrf_irq_n_0_1;
  wire nrf_miso_0_1;
  wire [7:0]ov7670_data_0_1;
  wire ov_pclk_0_1;
  wire resetn_0_1;
  wire rgb2dvi_1_TMDS_CLK_N;
  wire rgb2dvi_1_TMDS_CLK_P;
  wire [2:0]rgb2dvi_1_TMDS_DATA_N;
  wire [2:0]rgb2dvi_1_TMDS_DATA_P;
  wire [7:0]util_vector_logic_0_Res;
  wire [7:0]util_vector_logic_1_Res;
  wire [0:0]value_1_dout;
  wire vsync_0_1;
  wire [23:0]xlconcat_0_dout;

  assign clk_in1_0_1 = clk_in1_0;
  assign hdmi_out_clk_n = rgb2dvi_1_TMDS_CLK_N;
  assign hdmi_out_clk_p = rgb2dvi_1_TMDS_CLK_P;
  assign hdmi_out_data_n[2:0] = rgb2dvi_1_TMDS_DATA_N;
  assign hdmi_out_data_p[2:0] = rgb2dvi_1_TMDS_DATA_P;
  assign hdmi_out_hpd[0] = value_1_dout;
  assign href_0_1 = href_0;
  assign led0_0 = HDMI_MemController_0_led0;
  assign nrf_ce_0 = NRF24_TOP_TX_0_nrf_ce;
  assign nrf_csn_0 = NRF24_TOP_TX_0_nrf_csn;
  assign nrf_irq_n_0_1 = nrf_irq_n_0;
  assign nrf_miso_0_1 = nrf_miso_0;
  assign nrf_mosi_0 = NRF24_TOP_TX_0_nrf_mosi;
  assign nrf_sclk_0 = NRF24_TOP_TX_0_nrf_sclk;
  assign ov7670_data_0_1 = ov7670_data_0[7:0];
  assign ov7670_scl_0 = TOP_sccb_ctrl_0_ov7670_scl;
  assign ov_pclk_0_1 = ov_pclk_0;
  assign resetn_0_1 = resetn_0;
  assign vsync_0_1 = vsync_0;
  assign xclk[0] = clk_wiz_0_clk_25;
  design_1_DelayRegs_0_0 DelayRegs_0
       (.de_in(HDMI_Decoder_0_DE),
        .de_out(DelayRegs_0_de_out),
        .hs_in(HDMI_Decoder_0_h_sync),
        .hs_out(DelayRegs_0_hs_out),
        .pclk(clk_wiz_0_clk_25),
        .rstn(resetn_0_1),
        .vs_in(HDMI_Decoder_0_v_sync),
        .vs_out(DelayRegs_0_vs_out));
  design_1_DelayRegs_1_0 DelayRegs_1
       (.de_in(DelayRegs_0_de_out),
        .de_out(DelayRegs_1_de_out),
        .hs_in(DelayRegs_0_hs_out),
        .hs_out(DelayRegs_1_hs_out),
        .pclk(clk_wiz_0_clk_25),
        .rstn(resetn_0_1),
        .vs_in(DelayRegs_0_vs_out),
        .vs_out(DelayRegs_1_vs_out));
  design_1_Frame_4s_Stop_0_0 Frame_4s_Stop_0
       (.f2s_en(HDMI_MemController_0_cap_val),
        .f2s_val_out(Frame_4s_Stop_0_f2s_val_out),
        .pclk(clk_wiz_0_clk_25),
        .rstn(resetn_0_1),
        .y_pixel(HDMI_Decoder_0_y_pixel));
  design_1_Frame_Buffer_0_0 Frame_Buffer_0
       (.OE(HDMI_MemController_0_den),
        .WE(util_vector_logic_1_Res[0]),
        .ov_pclk(ov_pclk_0_1),
        .pclk(clk_wiz_0_clk_25),
        .rAddr(HDMI_MemController_0_rAddr),
        .rData(Frame_Buffer_0_rData),
        .wAddr(OV7670_Controller_0_wAddr),
        .wData(OV7670_Controller_0_wData));
  design_1_HDMI_Decoder_0_0 HDMI_Decoder_0
       (.DE(HDMI_Decoder_0_DE),
        .h_sync(HDMI_Decoder_0_h_sync),
        .pclk(clk_wiz_0_clk_25),
        .rstn(resetn_0_1),
        .v_sync(HDMI_Decoder_0_v_sync),
        .x_pixel(HDMI_Decoder_0_x_pixel),
        .y_pixel(HDMI_Decoder_0_y_pixel));
  design_1_HDMI_MemController_0_0 HDMI_MemController_0
       (.DE(HDMI_Decoder_0_DE),
        .Rom_Data(ImgROM_0_data),
        .b_port(HDMI_MemController_0_b_port),
        .cap_val(HDMI_MemController_0_cap_val),
        .den(HDMI_MemController_0_den),
        .g_port(HDMI_MemController_0_g_port),
        .h_out(RGB_to_HSV_0_h_out),
        .led0(HDMI_MemController_0_led0),
        .pclk(clk_wiz_0_clk_25),
        .rAddr(HDMI_MemController_0_rAddr),
        .rData(Frame_Buffer_0_rData),
        .r_port(HDMI_MemController_0_r_port),
        .rstn(resetn_0_1),
        .s_out(RGB_to_HSV_0_s_out),
        .v_out(RGB_to_HSV_0_v_out),
        .x_pixel(HDMI_Decoder_0_x_pixel),
        .y_pixel(HDMI_Decoder_0_y_pixel));
  design_1_ImgROM_0_0 ImgROM_0
       (.addr(HDMI_MemController_0_rAddr),
        .data(ImgROM_0_data));
  design_1_NRF24_TOP_TX_0_0 NRF24_TOP_TX_0
       (.cap_val(HDMI_MemController_0_cap_val),
        .clk(clk_wiz_0_clk_100),
        .nrf_ce(NRF24_TOP_TX_0_nrf_ce),
        .nrf_csn(NRF24_TOP_TX_0_nrf_csn),
        .nrf_irq_n(nrf_irq_n_0_1),
        .nrf_miso(nrf_miso_0_1),
        .nrf_mosi(NRF24_TOP_TX_0_nrf_mosi),
        .nrf_sclk(NRF24_TOP_TX_0_nrf_sclk),
        .rstn(resetn_0_1));
  design_1_OV7670_Controller_0_0 OV7670_Controller_0
       (.WE(OV7670_Controller_0_WE),
        .href(href_0_1),
        .ov7670_data(ov7670_data_0_1),
        .ov_pclk(ov_pclk_0_1),
        .rstn(resetn_0_1),
        .vsync(vsync_0_1),
        .wAddr(OV7670_Controller_0_wAddr),
        .wData(OV7670_Controller_0_wData));
  design_1_RGB_to_HSV_0_0 RGB_to_HSV_0
       (.h_out(RGB_to_HSV_0_h_out),
        .rData(Frame_Buffer_0_rData),
        .s_out(RGB_to_HSV_0_s_out),
        .v_out(RGB_to_HSV_0_v_out));
  design_1_TOP_sccb_ctrl_0_0 TOP_sccb_ctrl_0
       (.clk(clk_wiz_0_clk_100),
        .ov7670_scl(TOP_sccb_ctrl_0_ov7670_scl),
        .ov7670_sda(ov7670_sda_0),
        .rstn(resetn_0_1));
  design_1_Transformer_565_to_8_0_1 Transformer_565_to_8_0
       (.b_port_5(HDMI_MemController_0_b_port),
        .b_port_8(Transformer_565_to_8_0_b_port_8),
        .g_port_6(HDMI_MemController_0_g_port),
        .g_port_8(Transformer_565_to_8_0_g_port_8),
        .r_port_5(HDMI_MemController_0_r_port),
        .r_port_8(Transformer_565_to_8_0_r_port_8));
  design_1_clk_wiz_0_0 clk_wiz_0
       (.clk_100(clk_wiz_0_clk_100),
        .clk_125(clk_wiz_0_clk_125),
        .clk_25(clk_wiz_0_clk_25),
        .clk_in1(clk_in1_0_1),
        .resetn(resetn_0_1));
  design_1_rgb2dvi_1_0 rgb2dvi_1
       (.PixelClk(clk_wiz_0_clk_25),
        .SerialClk(clk_wiz_0_clk_125),
        .TMDS_Clk_n(rgb2dvi_1_TMDS_CLK_N),
        .TMDS_Clk_p(rgb2dvi_1_TMDS_CLK_P),
        .TMDS_Data_n(rgb2dvi_1_TMDS_DATA_N),
        .TMDS_Data_p(rgb2dvi_1_TMDS_DATA_P),
        .aRst_n(resetn_0_1),
        .vid_pData(xlconcat_0_dout),
        .vid_pHSync(DelayRegs_1_hs_out),
        .vid_pVDE(DelayRegs_1_de_out),
        .vid_pVSync(DelayRegs_1_vs_out));
  design_1_util_vector_logic_0_0 util_vector_logic_0
       (.Op1({Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out,Frame_4s_Stop_0_f2s_val_out}),
        .Res(util_vector_logic_0_Res));
  design_1_util_vector_logic_1_0 util_vector_logic_1
       (.Op1({OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE,OV7670_Controller_0_WE}),
        .Op2(util_vector_logic_0_Res),
        .Res(util_vector_logic_1_Res));
  design_1_xlconstant_0_0 value_1
       (.dout(value_1_dout));
  design_1_xlconcat_0_1 xlconcat_0
       (.In0(Transformer_565_to_8_0_g_port_8),
        .In1(Transformer_565_to_8_0_b_port_8),
        .In2(Transformer_565_to_8_0_r_port_8),
        .dout(xlconcat_0_dout));
endmodule
