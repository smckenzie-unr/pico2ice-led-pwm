-- ============================================================================
-- File Name    : led_controller.vhd
-- Project      : LED Controller
-- Author       : Scott L. McKenzie
-- Email        : fortyniners1234@gmail.com
-- Created      : December 13, 2025
-- Last Updated : December 13, 2025
-- 
-- Description  : Multi-channel PWM LED controller with trigger-based enable
--                control and configurable duty cycle per LED channel.
--
-- Control Register Format (8-bit):
--   Bit 7    : Trigger/Enable
--   Bits 6-4 : LED Channel Select (0 to C_NUM_LEDS-1)
--   Bits 3-0 : Duty Cycle (0-15, scaled by counter width)
--
-- License      : GNU General Public License v3.0
--
-- Copyright (C) 2025 Scott L. McKenzie
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- Revision History:
--   December 13, 2025 - Initial implementation
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ============================================================================
-- LED Controller Entity
-- ============================================================================
-- Description:
--   Configurable LED controller entity that manages multiple LEDs based on
--   input control signals. The controller is designed to operate with various
--   clock frequencies and can control a configurable number of LEDs.
--
-- Generics:
--   C_CLK_FREQ_MHZ  : Clock frequency in MHz (1 to 200, default 100)
--                     Used for timing calculations and delay generation
--   C_NUM_LEDS      : Number of LEDs to control (1 to 7, default 5)
--                     Determines the width of the LED_OUT port
--   C_COUNTER_WIDTH : Width of internal counters in bits (8 to 64, default 16)
--                     Affects timing resolution and maximum delay periods
--
-- Ports:
--   CLK     : System clock input
--   RESET_N : Active-low asynchronous reset
--   CONTROL : 8-bit control input vector for LED pattern/mode selection
--   LED_OUT : LED output vector, width determined by C_NUM_LEDS generic
--
-- Notes:
--   - Entity name appears to be "lcd_controller" but functionality is for LEDs
--   - All LEDs are controlled simultaneously through the single output vector
--   - Reset is active-low for compatibility with typical FPGA designs
-- ============================================================================
entity lcd_controller is
    generic(
        C_CLK_FREQ_MHZ  : integer range 1 to 200 := 100;
        C_NUM_LEDS      : integer range 1 to 7 := 5;
        C_COUNTER_WIDTH : integer range 8 to 64 := 16
    );
    port(
        CLK     : in std_logic;
        RESET_N : in std_logic;
        CONTROL : in std_logic_vector(7 downto 0);
        LED_OUT : out std_logic_vector(C_NUM_LEDS - 1 downto 0)
    );
end entity lcd_controller;



architecture rtl of lcd_controller is
    -- LED Controller Register and Signal Declarations
    -- 
    -- This section defines the internal registers, signals, and type definitions
    -- used by the LED controller module for PWM generation and control.

    -- Types:
    --   register_array: Array of unsigned counters for PWM timing
    type register_array is array (natural range <>) of unsigned(C_COUNTER_WIDTH - 1 downto 0);

    -- Subtypes:
    --   mux_range: Bit range (6 downto 4) for LED multiplexer selection
    --   dutycycle_range: Bit range (3 downto 0) for duty cycle configuration
    subtype mux_range is integer range 6 downto 4;
    subtype dutycycle_range is integer range 3 downto 0;

    -- Constants:
    --   trigger_bit: Bit position 7 for trigger control
    --   shift_amount: Calculated shift for counter width alignment
    constant trigger_bit    : integer := 7;
    constant shift_amount   : integer := C_COUNTER_WIDTH - 4;

    -- Signals:
    --   control_reg: Main control register for LED configuration
    --   enable_wire: Individual LED enable signals
    --   led_wire_out: LED output signals
    --   comp_regs: Comparison registers for PWM duty cycle thresholds
    --   count_regs: Counter registers for PWM timing generation
    signal control_reg      : std_logic_vector(CONTROL'range) := (others => '0');
    signal enable_wire      : std_logic_vector(C_NUM_LEDS - 1 downto 0) := (others => '0');
    signal led_wire_out     : std_logic_vector(C_NUM_LEDS - 1 downto 0) := (others => '0');
    signal comp_regs        : register_array(0 to C_NUM_LEDS - 1) := (others => (others => '0'));
    signal count_regs       : register_array(0 to C_NUM_LEDS - 1) := (others => (others => '1'));

    -- Aliases:
    --   trigger: Control bit for triggering LED operations
    --   led_mux_select: 3-bit field for selecting active LED
    --   led_duty_cycle: 4-bit field for setting PWM duty cycle
    alias trigger           : std_logic is control_reg(trigger_bit);
    alias led_mux_select    : std_logic_vector(2 downto 0) is control_reg(mux_range);
    alias led_duty_cycle    : std_logic_vector(3 downto 0) is control_reg(dutycycle_range);
begin
    -- LED Controller Implementation
    --
    -- This module implements a multi-channel LED PWM controller with the following processes:


    -- Internal led signal assigned to LED_OUT
    LED_OUT <= led_wire_out;

    -- control_reg_proc: Synchronous process that captures the CONTROL input signal
    --   - Resets control_reg to all zeros when RESET_N is low
    --   - Otherwise latches CONTROL input on rising clock edge
    control_reg_proc : process(CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET_N = '0') then
                control_reg <= (others => '0');
            else
                control_reg <= CONTROL;
            end if;
        end if;
    end process control_reg_proc;

    -- control_proc: Configuration process that updates LED enable and comparison registers
    --   - Operates on falling clock edge to avoid timing conflicts
    --   - Resets all comparison registers and enable signals during reset
    --   - Uses led_mux_select to determine which LED channel to configure
    --   - Updates enable signal and duty cycle comparison value for selected channel
    --   - Applies bit shifting to duty cycle value based on shift_amount
    control_proc: process(CLK) is
        variable enable_temp : std_logic_vector(C_NUM_LEDS - 1 downto 0);
        variable comp_temp   : register_array(0 to C_NUM_LEDS - 1);
    begin
        if (falling_edge(CLK)) then
            if (RESET_N = '0') then
                comp_regs   <= (others => (others => '0'));
                enable_wire <= (others => '0');
            else
                enable_temp := enable_wire;
                comp_temp := comp_regs;
                for bit_idx in 0 to C_NUM_LEDS - 1 loop
                    if to_integer(unsigned(led_mux_select)) = bit_idx then
                        enable_temp(bit_idx) := trigger;
                        comp_temp(bit_idx) := shift_left(resize(unsigned(led_duty_cycle), C_COUNTER_WIDTH), shift_amount);
                    end if;
                end loop;
                enable_wire <= enable_temp;
                comp_regs <= comp_temp;
            end if;
        end if;
    end process control_proc;

    -- counter_proc: PWM counter management process
    --   - Operates on rising clock edge
    --   - Maintains individual counters for each LED channel
    --   - Resets counters to all ones during system reset
    --   - Increments counters when corresponding enable signal is active
    --   - Resets individual counters to all ones when disabled
    counter_proc: process(CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET_N = '0') then
                count_regs <= (others => (others => '1'));
            else
                for bit_idx in 0 to C_NUM_LEDS - 1 loop
                    if (enable_wire(bit_idx) = '1') then
                        count_regs(bit_idx) <= count_regs(bit_idx) + 1;
                    else 
                        count_regs(bit_idx) <= (others => '1');
                    end if;
                end loop;
            end if;
        end if;
    end process counter_proc;

    -- led_gen: Generate block for PWM output logic
    --   - Creates PWM output for each LED channel
    --   - Output is high when counter value is less than comparison register
    --   - Provides individual PWM control for C_NUM_LEDS channels
    led_gen: for idx in 0 to C_NUM_LEDS - 1 generate
        led_wire_out(idx) <= '1' when (count_regs(idx) < comp_regs(idx)) else '0';
    end generate led_gen;

end architecture rtl;