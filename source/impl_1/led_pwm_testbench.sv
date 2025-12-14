`timescale 1ns / 1ps


module led_pwm_testbench;
    parameter CLK_PERIOD = 10; //nanoseconds
    parameter NUM_LEDS = 5;

    logic clk;
    logic reset;
    logic [7:0] control;
    logic [NUM_LEDS - 1:0] leds;

    // Instantiate your LED PWM module
    lcd_controller #(
        .C_NUM_LEDS(NUM_LEDS),
        .C_COUNTER_WIDTH(8)
    ) dut (
        .CLK(clk),
        .RESET_N(reset),
        .CONTROL(control),
        .LED_OUT(leds)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        clk = 0;
        reset = 0;
        control = 8'b0;

        $display("Simulation started at %0t", $time);

        #1000 begin
            reset = 1;
            $display("Time %0t: Reset set high", $time);
        end

        // Test LED 1
        for (int i = 0; i < 16; i++) begin
            #2600 begin
                control = {1'b1, 3'b000, i[3:0]};
                $display("Setting control to 0x%x at %0t", control, $time);
            end
        end

        // Test LED 2
        for (int i = 0; i < 16; i++) begin
            #2600 begin
                control = {1'b1, 3'b001, i[3:0]};
                $display("Setting control to 0x%x at %0t", control, $time);
            end
        end

        // Test LED 3
        for (int i = 0; i < 16; i++) begin
            #2600 begin
                control = {1'b1, 3'b010, i[3:0]};
                $display("Setting control to 0x%x at %0t", control, $time);
            end
        end

        // Test LED 4
        for (int i = 0; i < 16; i++) begin
            #2600 begin
                control = {1'b1, 3'b011, i[3:0]};
                $display("Setting control to 0x%x at %0t", control, $time);
            end
        end

        // Test LED 5
        for (int i = 0; i < 16; i++) begin
            #2600 begin
                control = {1'b1, 3'b100, i[3:0]};
                $display("Setting control to 0x%x at %0t", control, $time);
            end
        end

        // Disable all LEDs
        #609000 $display("Disabling all LEDs at %0t", $time); //these times are not correct but for now they work
        for (int led = 0; led < NUM_LEDS; led++) begin
            #100 begin
                control = {1'b0, 3'(led), 4'b0000};  // Enable=0, LED select, duty=0
                $display("Disabling LED %0d (control=0x%x) at %0t", led, control, $time);
            end
        end

        #609100 begin //need to recalculate time here runs to long
            $display("Simulation finished at %0t", $time);
            $finish;
        end
    end

endmodule