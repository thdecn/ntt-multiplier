-- -------------------------------------------------------------------------- --
-- Engineer: Thomas De Cnudde
--
-- Create Date: 19/01/2021
-- Design Name:
-- Module Name: ntt_multiplier
-- Project Name:
-- Description:
--
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

entity ntt_multiplier is
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
end entity;

architecture rtl of ntt_multiplier is

  -- Component Declarations
  component bram_tdp is
    generic (
      data : integer;
      addr : integer
    );
    port (
      -- Port A
      a_clk : in std_logic;
      a_wr : in std_logic;
      a_addr : in std_logic_vector(addr-1 downto 0);
      a_din : in std_logic_vector(data-1 downto 0);
      a_dout : out std_logic_vector(data-1 downto 0);
      -- Port B
      b_clk : in std_logic;
      b_wr : in std_logic;
      b_addr : in std_logic_vector(addr-1 downto 0);
      b_din : in std_logic_vector(data-1 downto 0);
      b_dout : out std_logic_vector(data-1 downto 0)
    );
  end component;

  component multiplier is
    generic (data_width : integer; q : integer);
    port(
      -- Inputs
      clk : in std_logic;
      a, b : in std_logic_vector(data_width-1 downto 0);
      -- Outpus
      c : out std_logic_vector(data_width-1 downto 0)
    );
  end component;

  component ntt_control is
    generic (
      n : integer; -- Power of 2
      n_inv : integer;
      q : integer; -- q = 1 mod 2n
      data_width : integer; -- ceil(log2(q))
      n_width : integer -- ceil(log2(n))
    );
    port (
      -- Inputs
      clk, rst : in std_logic;
      start : in std_logic;
      fwd_bwd : in std_logic; -- 0: fwd, 1: bwd
      -- Outputs
      m : out std_logic_vector(n_width-1 downto 0); -- max(m) == n
      t : out std_logic_vector(n_width-1 downto 0); -- max(t) == n
      i : out std_logic_vector(n_width-2 downto 0); -- max(i) == m/2
      j : out std_logic_vector((n_width)+(n_width-1) downto 0); -- max(j) == 2*t*i => len(t)+len(i)+1
      h : out std_logic_vector(n_width-1 downto 0);
      done : out std_logic
    );
  end component;

  signal n_counter_reg, n_counter_next : std_logic_vector(n_width-1 downto 0);
  signal mult_counter_reg, mult_counter_next : std_logic_vector(n_width downto 0); --__TODO__ Change width dyn

  signal a_wr_reg, a_wr_next : std_logic;
  signal a_addr_reg, a_addr_next, b_addr_reg, b_addr_next : std_logic_vector(addr-1 downto 0);
  signal a_din1, a_din2, b_dout1, b_dout2 : std_logic_vector(data_width-1 downto 0);

  signal mult_in1_reg, mult_in1_next : std_logic_vector(data_width-1 downto 0);
  signal mult_in2_reg, mult_in2_next : std_logic_vector(data_width-1 downto 0);
  signal mult_out : std_logic_vector(data_width-1 downto 0);

  signal fwd_bwd_reg, fwd_bwd_next : std_logic;
  signal ntt_start, ntt_done : std_logic;

  signal m : std_logic_vector(n_width-1 downto 0);
  signal t : std_logic_vector(n_width-1 downto 0);
  signal i : std_logic_vector(n_width-2 downto 0);
  signal j : std_logic_vector((n_width)+(n_width-1) downto 0);
  signal h : std_logic_vector(n_width-1 downto 0);

  type state_type is (IDLE_STATE, LOAD_STATE, CMULT_STATE, FNTT_STATE, BNTT_STATE, READ_STATE, DONE_STATE);
  signal state_reg, state_next : state_type;

begin

  data_out1 <= b_dout1; -- __TODO__ when read_state_mux else
  data_out2 <= b_dout2; -- __TODO__ when read_state_mux else

  ram_memory_a : bram_tdp
  generic map(data => data_width, addr => addr)
  port map(
    a_clk => clk,
    a_wr => a_wr_reg,
    a_addr => a_addr_reg,
    a_din => a_din1,
    a_dout => open,
    -- Port B
    b_clk => clk,
    b_wr => '0',
    b_addr => b_addr_reg,
    b_din => (others => '0'),
    b_dout => b_dout1 );

  ram_memory_b : bram_tdp
  generic map(data => data_width, addr => addr)
  port map(
    a_clk => clk,
    a_wr => a_wr_reg,
    a_addr => a_addr_reg,
    a_din => a_din2, 
    a_dout => open,
    -- Port B
    b_clk => clk,
    b_wr => '0',
    b_addr => b_addr_reg,
    b_din => (others => '0'),
    b_dout => b_dout2 );

  mult: multiplier generic map(data_width => data_width, q => q)
  port map(clk => clk, a => mult_in1_reg, b => mult_in2_reg, c => mult_out);

  ntt_controler: ntt_control
    generic map ( n => n, n_inv => n_inv, q => q, data_width => data_width, n_width => n_width )
    port map (
      clk => clk, rst => rst, start => ntt_start, fwd_bwd => fwd_bwd_reg,
      m => m, t => t, i => i, j => j, h => h,
      done => ntt_done );

  process(clk)
  begin
    if rst='1' then
      n_counter_reg <= (others => '0');
      state_reg <= IDLE_STATE;
      a_wr_reg <= '0';
      a_addr_reg <= (others => '0');
      b_addr_reg <= (others => '0');
      mult_in1_reg <= (others => '0');
      mult_in2_reg <= (others => '0');
      mult_counter_reg <= (others => '0');
      fwd_bwd_reg <= '0';
    elsif rising_edge(clk) then
      n_counter_reg <= n_counter_next;
      state_reg <= state_next;
      a_wr_reg <= a_wr_next;
      a_addr_reg <= a_addr_next;
      b_addr_reg <= b_addr_next;
      mult_in1_reg <= mult_in1_next;
      mult_in2_reg <= mult_in2_next;
      mult_counter_reg <= mult_counter_next;
      fwd_bwd_reg <= fwd_bwd_next;
    end if;
  end process;

  FSM : process(state_reg, instruction, n_counter_reg, a_wr_reg, a_addr_reg, b_addr_reg, mult_in1_reg, mult_in2_reg, mult_counter_reg, data_in1, data_in2, mult_out, fwd_bwd_reg, ntt_done)
  begin
    -- Default assignations to avoid latches
    state_next <= state_reg;
    n_counter_next <= n_counter_reg;
    a_wr_next <= a_wr_reg;
    a_addr_next <= a_addr_reg;
    b_addr_next <= b_addr_reg;
    mult_in1_next <= mult_in1_reg;
    mult_in2_next <= mult_in2_reg;
    mult_counter_next <= mult_counter_reg;
    fwd_bwd_next <= fwd_bwd_reg;

    a_din1 <= (others => '0');
    a_din2 <= (others => '0');
    ntt_start <= '0';
    done <= '0';

    case( state_reg ) is
      when IDLE_STATE =>
        if instruction="00001" then
          n_counter_next <= (others => '0');
          a_wr_next <= '1';
          a_addr_next <= (others => '0');
          state_next <= LOAD_STATE;
        elsif instruction="00010" then
          n_counter_next <= (others => '0');
          b_addr_next <= (others => '0');
          state_next <= READ_STATE;
        elsif instruction="00100" then
          mult_counter_next <= (others => '0');
          b_addr_next <= (others => '0');
          state_next <= CMULT_STATE;
        elsif instruction="01000" then
          state_next <= FNTT_STATE;
          fwd_bwd_next <= '0';
        elsif instruction="10000" then
          state_next <= BNTT_STATE;
          fwd_bwd_next <= '1';
        end if;

      when LOAD_STATE =>
        a_din1 <= data_in1;
        a_din2 <= data_in2;
        if to_integer(unsigned(n_counter_reg))=n-1 then
          state_next <= DONE_STATE;
          a_wr_next <= '0';
          a_addr_next <= (others => '0');
        else
          n_counter_next <= std_logic_vector(unsigned(n_counter_reg) + 1);
          a_wr_next <= '1';
          a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
        end if;

      when CMULT_STATE =>
        if to_integer(unsigned(mult_counter_reg))=n-1+1+1+1 then -- +1 for mult input regs, +1 for mult regs + 1 for write to ram
          state_next <= DONE_STATE;
          b_addr_next <= (others => '0');
          a_wr_next <= '0';
          a_addr_next <= (others => '0');
          a_din1 <= mult_out;
          a_din2 <= (others => '0');
        elsif to_integer(unsigned(mult_counter_reg))>=n-1 then
          mult_counter_next <= std_logic_vector(unsigned(mult_counter_reg) + 1);
          b_addr_next <= (others => '0');
          mult_in1_next <= b_dout1;
          mult_in2_next <= b_dout2;
          a_wr_next <= '1';
          a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
          a_din1 <= mult_out;
          a_din2 <= (others => '0');
        else
          if to_integer(unsigned(b_addr_reg))=1+1 then
            a_wr_next <= '1';
            a_addr_next <= (others => '0');
          elsif to_integer(unsigned(b_addr_reg))>1+1 then
            a_wr_next <= '1';
            a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
            a_din1 <= mult_out;
            a_din2 <= (others => '0');
          end if;
          mult_counter_next <= std_logic_vector(unsigned(mult_counter_reg) + 1);
          b_addr_next <= std_logic_vector(unsigned(b_addr_reg) + 1);
          mult_in1_next <= b_dout1;
          mult_in2_next <= b_dout2;
        end if;

      when FNTT_STATE =>
        if ntt_done='1' then
          state_next <= DONE_STATE;
          ntt_start <= '0';
        else
          ntt_start <= '1';
        end if;

      when BNTT_STATE =>
        if ntt_done='1' then
          state_next <= DONE_STATE;
          ntt_start <= '0';
        else
          ntt_start <= '1';
        end if;

      when READ_STATE =>
        if to_integer(unsigned(n_counter_reg))=n-1 then
          state_next <= DONE_STATE;
          b_addr_next <= (others => '0');
        else
          n_counter_next <= std_logic_vector(unsigned(n_counter_reg) + 1);
          b_addr_next <= std_logic_vector(unsigned(b_addr_reg) + 1);
        end if;

      when DONE_STATE =>
        done <= '1';
        state_next <= IDLE_STATE;

      when others =>
        state_next <= IDLE_STATE;

    end case;
  end process;

end architecture;
