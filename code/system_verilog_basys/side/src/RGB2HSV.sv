`timescale 1ns / 1ps

module RGB_to_HSV (
    input  logic [15:0] rData, // RGB (R:5, G:6, B:5)
    output logic [ 9:0] h_out, // Hue (0-360 degrees)
    output logic [ 6:0] s_out, // Saturation (0-100%)
    output logic [ 6:0] v_out  // Value (0-100%)
);
    // RGB 채널 분리
    logic [5:0] r_in_scaled;
    logic [5:0] g_in_scaled;
    logic [5:0] b_in_scaled;

    // 0-63 범위로 스케일링 (5,6,5 -> 6,6,6)
    assign r_in_scaled = {rData[15:11], 1'b0};
    assign g_in_scaled = rData[10:5];
    assign b_in_scaled = {rData[4:0], 1'b0};

    // RGB 중 최댓값과 최솟값 찾기
    logic [5:0] max_val, min_val;
    logic [5:0] delta;

    assign max_val = (r_in_scaled > g_in_scaled) ? 
                     ((r_in_scaled > b_in_scaled) ? r_in_scaled : b_in_scaled) : 
                     ((g_in_scaled > b_in_scaled) ? g_in_scaled : b_in_scaled);

    assign min_val = (r_in_scaled < g_in_scaled) ? 
                     ((r_in_scaled < b_in_scaled) ? r_in_scaled : b_in_scaled) : 
                     ((g_in_scaled < b_in_scaled) ? g_in_scaled : b_in_scaled);
    
    // 명도(V) 채도(S) 계산
    assign delta = max_val - min_val;
    assign v_out = (max_val * 100) / 63; // Scale 0-63 to 0-100

    assign s_out = (max_val == 0) ? 7'b0 : (delta * 100) / max_val;

    // 색조(H) 계산
    logic [11:0] h_temp;
    
    always_comb begin
        if (delta == 0) begin
            h_temp = 0; // Grayscale
        end else if (max_val == r_in_scaled) begin
            h_temp = (60 * (g_in_scaled - b_in_scaled) / delta);
        end else if (max_val == g_in_scaled) begin
            h_temp = (60 * (b_in_scaled - r_in_scaled) / delta) + 120;
        end else begin // max_val == b_in_scaled
            h_temp = (60 * (r_in_scaled - g_in_scaled) / delta) + 240;
        end
        // Hue 값이 음수인 경우
        if (h_temp < 0) begin
            h_out = h_temp + 360;
        end else begin
            h_out = h_temp;
        end
    end

endmodule