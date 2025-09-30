`timescale 1ns / 1ps

module HDMI_MemController #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter H_MAX = 800,
    parameter V_MAX = 525
) (
    input                          pclk,
    input                          rstn,
    // Decoder Side
    input                          DE,
    input      [$clog2(H_MAX)-1:0] x_pixel,
    input      [$clog2(V_MAX)-1:0] y_pixel,
    // frame buffer Side
    output                         den,
    output                         cap_val,    // f2s_en
    output     [             15:0] led_count,
    output reg [             16:0] rAddr,
    input      [             15:0] rData,      // RGB-565 : 16bit
    //ImgROM side
    input      [             15:0] Rom_Data,
    // HSV Side
    input      [              9:0] h_out,
    input      [              6:0] s_out,
    input      [              6:0] v_out,
    // =================================================================
    // 수정된 부분 1: 출력을 5, 6, 5 bit 포트로 분리
    // =================================================================
    output reg [              4:0] r_port,
    output reg [              5:0] g_port,
    output reg [              4:0] b_port,
    output                         led0
);

  wire [3:0] reg_r, reg_g, reg_b;
  reg reg_cap_val, next_cap_val;
  reg strike, ball;
  wire left_green_val;

  reg [14:0] thr_cnt, thr_cnt_next;

  reg [7:0] startup_delay_cnt;
  reg       system_ready;

  assign cap_val   = reg_cap_val;
  assign led_count = {left_green_val, thr_cnt};

  assign reg_r     = (rData[15:12] == 0 | rData[15:12] == 4'hf) ? rData[15:12] : rData[15:12] - 1;
  assign reg_g     = (rData[10:7] == 0 | rData[10:7] == 4'hf) ? rData[10:7] : rData[10:7] - 1;
  assign reg_b     = rData[4:1];

  assign den       = (DE && (x_pixel < (IMG_W << 1)) && (y_pixel < (IMG_H << 1)));  // upscale 

  // 추가
  assign led0      = left_green_val;

  Green_Counter #(
      .H_MAX(H_MAX),
      .V_MAX(V_MAX)
  ) U_Green_Counter (
      .pclk(pclk),
      .rstn(rstn),
      .den(den),
      .h_out(h_out),
      .s_out(s_out),
      .v_out(v_out),
      .x_pixel(x_pixel),
      .y_pixel(y_pixel),
      .left_green_val(left_green_val)
  );

  localparam IDLE = 2'b00;
  localparam RECOGNIZE = 2'b01;
  localparam THROWING = 2'b10;

  reg [1:0] state, next_state;

  // =================================================================
  // 수정된 부분 2: always 블록에서 분리된 r/g/b_port에 값 할당
  // =================================================================
  always @(*) begin
    rAddr = 17'bz;
    {r_port, g_port, b_port} = 16'b0;  // Default: Black
    if (den) begin
      rAddr = ((y_pixel / 2) * 320 + (x_pixel / 2));
      if (x_pixel >= 400 && x_pixel < 404) begin
        // 빨간색 라인 표시 (RGB-565)
        {r_port, g_port, b_port} = 16'hF800;
      end else if(((h_out >= 10'd30) && (h_out <= 10'd38) &&
                                        (s_out >= 7'd59) && (s_out <= 7'd63) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd60) && (h_out <= 10'd64) &&
                                        (s_out >= 7'd46) && (s_out <= 7'd51) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd10) && (h_out <= 10'd33) &&
                                        (s_out >= 7'd55) && (s_out <= 7'd76) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                         ((h_out >= 10'd20) && (h_out <= 10'd42) &&
                                        (s_out >= 7'd44) && (s_out <= 7'd63) &&
                                        (v_out >= 7'd96) && (v_out <= 7'd100)))begin
        // HSV 조건 만족 시 파란색 표시 (RGB-565)
        {r_port, g_port, b_port} = 16'h001f;
      end else if (((reg_g + 1) > reg_r + 3) && ((reg_g + 1) >= reg_b + 1) && 
                         ((reg_g + 1) >= 1))  begin
        {r_port, g_port, b_port} = Rom_Data;  // Rom_Data를 그대로 출력
      end else begin
        {r_port, g_port, b_port} = rData;  // rData를 그대로 출력
      end
    end
  end

  always @(posedge pclk or negedge rstn) begin
    if (~rstn) begin
      startup_delay_cnt <= 0;
      system_ready      <= 1'b0;
    end else begin
      if (!system_ready) begin
        if ((x_pixel == 639) && (y_pixel == 479)) begin
          if (startup_delay_cnt < 10) begin
            startup_delay_cnt <= startup_delay_cnt + 1;
          end else begin
            system_ready <= 1'b1;
          end
        end
      end
    end
  end

  always @(posedge pclk or negedge rstn) begin
    if (~rstn) begin
      state       <= IDLE;
      reg_cap_val <= 1'b0;
      thr_cnt     <= 0;
    end else begin
      state       <= next_state;
      reg_cap_val <= next_cap_val;
      thr_cnt     <= thr_cnt_next;
    end
  end

  always @(*) begin
    next_state   = state;
    next_cap_val = reg_cap_val;
    thr_cnt_next = thr_cnt;
    case (state)
      IDLE: begin
        next_cap_val = 1'b0;
        if (system_ready && left_green_val) begin
          next_cap_val = 1;
          thr_cnt_next = thr_cnt + 1;
          next_state   = THROWING;
        end
      end
      THROWING: begin
        next_cap_val = 0;
        if ((x_pixel == 639) && (y_pixel == 479) && !(left_green_val)) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule


module Green_Counter #(
    parameter H_MAX = 800,
    parameter V_MAX = 525
) (
    input pclk,
    input rstn,
    input den,
    input [9:0] h_out,
    input [6:0] s_out,
    input [6:0] v_out,
    input [$clog2(H_MAX)-1:0] x_pixel,
    input [$clog2(V_MAX)-1:0] y_pixel,
    output left_green_val
);

  reg left_green_val_reg;
  reg [2:0] left_green_cnt;

  assign left_green_val = left_green_val_reg;

  always @(posedge pclk or negedge rstn) begin
    if (~rstn) begin
      left_green_cnt <= 0;
      left_green_val_reg <= 0;
    end else begin
      if (den) begin
        if ((x_pixel < 400) && (x_pixel >= 50)) begin
          if (((h_out >= 10'd30) && (h_out <= 10'd38) &&
                                        (s_out >= 7'd59) && (s_out <= 7'd63) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd60) && (h_out <= 10'd64) &&
                                        (s_out >= 7'd46) && (s_out <= 7'd51) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                        ((h_out >= 10'd10) && (h_out <= 10'd33) &&
                                        (s_out >= 7'd55) && (s_out <= 7'd76) &&
                                        (v_out >= 7'd98) && (v_out <= 7'd100)) ||
                                         ((h_out >= 10'd20) && (h_out <= 10'd42) &&
                                        (s_out >= 7'd44) && (s_out <= 7'd63) &&
                                        (v_out >= 7'd96) && (v_out <= 7'd100))) begin
            if (left_green_cnt < 5) begin
              left_green_cnt <= left_green_cnt + 1;
            end else begin
              left_green_val_reg <= 1;
            end
          end
        end
      end else begin
        if (y_pixel == 524) begin
          left_green_cnt <= 0;
          left_green_val_reg <= 0;
        end
      end
    end
  end

endmodule
