-- -------------------------------------------------------------------------- --
-- Engineer: Thomas De Cnudde
--
-- Create Date: 19/01/2021
-- Design Name:
-- Module Name: tb_ntt_multiplier
-- Project Name:
-- Description:
--     VHDL Test Bench for module: ntt_multiplier.vhd
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--    TODO:
--      1.
--      2.
--      3.
--
-- -------------------------------------------------------------------------- --
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ntt_multiplier is
end tb_ntt_multiplier;

architecture behavior of tb_ntt_multiplier is

  shared variable data_width : integer := 10;
  shared variable addr : integer := 4;
  shared variable n : integer := 8;
  shared variable n_inv : integer := 589;
  shared variable q : integer := 673; -- q = 1 mod 2n
  shared variable n_width : integer := 3+1;

  -- Component Declaration for the Unit Under Test (UUT)
  component ntt_multiplier is
    generic (
      data_width : integer := 10;
      addr : integer := 4;
      n : integer; -- Power of 2
      n_inv : integer;
      q : integer; -- q = 1 mod 2n
      n_width : integer -- ceil(log2(n))
    );
    port (
      -- Inputs
      clk, rst : in std_logic;
      start : in std_logic;
      instruction : in std_logic_vector(4 downto 0);
      data_in1, data_in2 : in std_logic_vector(data_width-1 downto 0);
      -- Outputs
      data_out1, data_out2 : out std_logic_vector(data_width-1 downto 0);
      done : out std_logic
    );
  end component;

  --Inputs
  signal clk, rst : std_logic := '0';
  signal start : std_logic := '0';
  signal instruction : std_logic_vector(4 downto 0);
  signal data_in1, data_in2 : std_logic_vector(data_width-1 downto 0);
  --Outputs
  signal data_out1, data_out2 : std_logic_vector(data_width-1 downto 0);
  signal done : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin

   -- Clock process
   clk_process : process
   begin
      clk <= '0';
      wait for CLK_PERIOD/2; -- for half of clock period clk stays at '0'.
      clk <= '1';
      wait for CLK_PERIOD/2; -- for next half of clock period clk stays at '1'.
   end process;

  -- Instantiate the Unit Under Test (UUT)
  uut : ntt_multiplier
  generic map(data_width => data_width, addr => addr, n => n, n_inv => n_inv, q => q, n_width => n_width)
  port map( clk => clk, rst => rst, start => start, instruction => instruction,
            data_in1 => data_in1, data_in2 => data_in2,
            data_out1 => data_out1, data_out2 => data_out2, done => done );

  tb_proc : process --generate values
    begin
      data_in1 <= (others => '0');
      data_in2 <= (others => '0');
      start <= '0';
      instruction <= "00000";
      rst <= '0';
      wait for CLK_PERIOD*10;
      rst <= '1';
      wait for CLK_PERIOD*10;
      rst <= '0';
      wait for CLK_PERIOD*10;

      -- LOAD --
      instruction <= "00001";
      wait for CLK_PERIOD;
      instruction <= "00000";

      -- a = np.array([4,1,4,2,1,3,5,6])
      -- b = np.array([6,1,8,0,3,3,9,8])
      data_in1 <= std_logic_vector(to_unsigned(6, data_width));
      data_in2 <= std_logic_vector(to_unsigned(4, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(1, data_width));
      data_in2 <= std_logic_vector(to_unsigned(1, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(8, data_width));
      data_in2 <= std_logic_vector(to_unsigned(4, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(0, data_width));
      data_in2 <= std_logic_vector(to_unsigned(2, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(3, data_width));
      data_in2 <= std_logic_vector(to_unsigned(1, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(3, data_width));
      data_in2 <= std_logic_vector(to_unsigned(3, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(9, data_width));
      data_in2 <= std_logic_vector(to_unsigned(5, data_width));
      wait for CLK_PERIOD;
      data_in1 <= std_logic_vector(to_unsigned(8, data_width));
      data_in2 <= std_logic_vector(to_unsigned(6, data_width));
      wait for CLK_PERIOD;

--  __TODO__  wait until done='1';
      -- READ --
      wait for CLK_PERIOD*20;
      instruction <= "00010";
      wait for CLK_PERIOD;
      instruction <= "00000";

      -- CMULT -- Coefficient-wise multiplication 
      wait for CLK_PERIOD*20;
      instruction <= "00100";
      wait for CLK_PERIOD;
      instruction <= "00000";

      -- READ --
      wait for CLK_PERIOD*20;
      instruction <= "00010";
      wait for CLK_PERIOD;
      instruction <= "00000";

      -- FNTT -- fwdNTT
      wait for CLK_PERIOD*20;
      instruction <= "01000";
      wait for CLK_PERIOD;
      instruction <= "00000";
      wait until done='1';

      -- BNTT -- bwdNTT
      wait for CLK_PERIOD*20;
      instruction <= "10000";
      wait for CLK_PERIOD;
      instruction <= "00000";
      wait until done='1';

      -- READ --
      wait for CLK_PERIOD*20;
      instruction <= "00010";
      wait for CLK_PERIOD;
      instruction <= "00000";

      wait for CLK_PERIOD*20;
      wait for CLK_PERIOD*20;
      wait for CLK_PERIOD*20;

    assert (false) report
    "Simulation successful (not a failure).  No problems detected. "
    severity failure;
  end process;

end;
