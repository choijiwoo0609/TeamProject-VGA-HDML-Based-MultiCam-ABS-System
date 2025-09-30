// Testbench for the design_1_wrapper module.
// Since this is a complex system involving HDMI, Camera (OV7670), and nRF radio,
// this testbench provides basic clock/reset sequences and simple stimulus
// to ensure the system starts up and registers basic input activity.

`timescale 1 ns / 1 ps
`define CLK_PERIOD 10

module design_1_wrapper_tb;

    // -------------------------------------------------------------------------
    // 1. Testbench Signals (reg for inputs, wire for outputs)
    // -------------------------------------------------------------------------

    // Clock and Reset Inputs
    reg clk_in1_0;
    reg resetn_0;

    // OV7670 Camera Inputs
    reg href_0;         // Horizontal reference (Active High)
    reg ov_pclk_0;      // Pixel Clock (Simulated)
    reg vsync_0;        // Vertical Sync (Active High)
    reg [7:0] ov7670_data_0; // 8-bit Camera Data

    // nRF Radio Inputs
    reg nrf_irq_n_0;    // Interrupt (Active Low)
    reg nrf_miso_0;     // SPI MISO

    // Inout Port Handling (I2C SDA for OV7670)
    // ov7670_sda_0 will be the actual wire connected to the DUT.
    wire ov7670_sda_0;
    reg ov7670_sda_driver_tb; // Value driven by TB (when TB is Master)
    reg ov7670_sda_en_tb;     // Enable for TB driver (1'b1 to drive, 1'b0 to let DUT drive or float)

    // Outputs to Monitor
    wire hdmi_out_clk_n;
    wire hdmi_out_clk_p;
    wire [2:0] hdmi_out_data_n;
    wire [2:0] hdmi_out_data_p;
    wire [0:0] hdmi_out_hpd;
    wire led0_0;
    wire nrf_ce_0;
    wire nrf_csn_0;
    wire nrf_mosi_0;
    wire nrf_sclk_0;
    wire ov7670_scl_0; // I2C SCL
    wire [0:0] xclk; // Camera Master Clock

    // -------------------------------------------------------------------------
    // 2. Inout Tristate Logic
    // -------------------------------------------------------------------------

    // When TB drives (sda_en_tb is high), drive the value; otherwise, set to Z (High Impedance).
    // This allows the DUT to drive the signal when the TB releases it.
    assign ov7670_sda_0 = ov7670_sda_en_tb ? ov7670_sda_driver_tb : 1'bZ;

    // -------------------------------------------------------------------------
    // 3. DUT Instantiation
    // -------------------------------------------------------------------------

    design_1_wrapper DUT (
        .clk_in1_0(clk_in1_0),
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
        .xclk(xclk)
    );

    // -------------------------------------------------------------------------
    // 4. Clock Generation
    // -------------------------------------------------------------------------

    // Generate the main input clock clk_in1_0
    initial begin
        clk_in1_0 = 1'b0;
    end

    always #(`CLK_PERIOD / 2) clk_in1_0 = ~clk_in1_0;

    // -------------------------------------------------------------------------
    // 5. Stimulus Generation
    // -------------------------------------------------------------------------

    initial begin
        // Initialize all inputs
        resetn_0 = 1'b0;
        href_0 = 1'b0;
        ov_pclk_0 = 1'b0;
        vsync_0 = 1'b0;
        ov7670_data_0 = 8'h00;
        nrf_irq_n_0 = 1'b1; // Default to inactive (active low)
        nrf_miso_0 = 1'b0;

        // Initialize I2C inout driver (released, assuming pull-up on the line)
        ov7670_sda_driver_tb = 1'b1; // Drive high when enabled
        ov7670_sda_en_tb = 1'b0;     // Released (let DUT/pull-up manage)

        // Wait for a short time
        #(`CLK_PERIOD * 2);

        // Apply Reset (Active Low)
        $display("[%0t] Applying Reset...", $time);
        resetn_0 = 1'b0;
        #(`CLK_PERIOD * 10);

        // Release Reset
        $display("[%0t] Releasing Reset. System should now configure and run.", $time);
        resetn_0 = 1'b1;
        #(`CLK_PERIOD * 100);

        // --- Test 1: Simulate Camera Activity ---

        $display("[%0t] Starting Camera Simulation (vsync, pclk, href toggle)...", $time);

        // Simulate Vertical Sync
        vsync_0 = 1'b1;
        #(`CLK_PERIOD * 10);
        vsync_0 = 1'b0;

        // Simulate Pixel Clock and Data stream for a few cycles
        repeat (20) begin
            ov_pclk_0 = 1'b1;
            #(`CLK_PERIOD / 2);
            ov7670_data_0 = ov7670_data_0 + 8'd1; // Dummy incrementing data
            href_0 = 1'b1; // Active line
            ov_pclk_0 = 1'b0;
            #(`CLK_PERIOD / 2);
        end
        href_0 = 1'b0;

        // --- Test 2: Simulate I2C Configuration Attempt (TB acting as Master) ---
        // This is a minimal, illustrative I2C sequence to check connectivity.

        $display("[%0t] Simulating I2C communication (TB drives SDA)...", $time);
        // Step 1: Start Condition (SCL high, SDA falls)
        ov7670_sda_en_tb = 1'b1; // TB takes control
        ov7670_sda_driver_tb = 1'b1; // SDA initial high (if line is pull-up)
        #(`CLK_PERIOD * 2);

        // Assuming DUT will drive SCL (ov7670_scl_0)
        // Simulate an I2C transaction
        ov7670_sda_driver_tb = 1'b0; // SDA fall (Start condition)
        #(`CLK_PERIOD * 2);

        // Wait for DUT to react (e.g., generate XCLK, drive HDMI output, or perform I2C setup)
        $display("[%0t] Observing Outputs (HDMI, LED, NRF, XCLK)...", $time);
        #(`CLK_PERIOD * 50);

        // Step 2: Stop Condition (SCL high, SDA rises)
        ov7670_sda_driver_tb = 1'b1; // SDA rise (Stop condition)
        #(`CLK_PERIOD * 2);
        ov7670_sda_en_tb = 1'b0; // TB releases control (let DUT/pull-up manage)
        $display("[%0t] I2C stop condition, TB released SDA.", $time);


        // --- Test 3: Simulate nRF Interrupt & MISO data ---
        $display("[%0t] Simulating nRF Interrupt and MISO data...", $time);
        nrf_irq_n_0 = 1'b0; // Assert interrupt
        nrf_miso_0 = 1'b1;  // MISO high
        #(`CLK_PERIOD * 10);
        nrf_miso_0 = 1'b0;
        #(`CLK_PERIOD * 10);
        nrf_irq_n_0 = 1'b1; // De-assert interrupt

        // Final Wait and Stop Simulation
        #(`CLK_PERIOD * 200);
        $display("[%0t] Simulation Finished.", $time);
        $stop;
    end

    // Optional: Monitoring the DUT's attempt to drive SDA
    // This process can be complex. For a basic check, we just display the state.
    always @(ov7670_sda_0 or ov7670_scl_0) begin
        if (ov7670_sda_en_tb == 1'b0) begin
            // TB is not driving; check if DUT is driving the line
            if (ov7670_scl_0 === 1'b1) begin
                $display("[%0t] I2C Bus: SCL=1, SDA=%b (Monitor)", $time, ov7670_sda_0);
            end
        end
    end

    // Optional: Log major output changes
    initial begin
        $monitor("[%0t] LED=%b | XCLK=%b | HDMI_CLK_P=%b | NRF_CSN=%b | NRF_SCLK=%b",
            $time, led0_0, xclk, hdmi_out_clk_p, nrf_csn_0, nrf_sclk_0);
    end

endmodule
