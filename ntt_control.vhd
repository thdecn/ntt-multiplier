-- -------------------------------------------------------------------------- --
-- Engineer: Thomas De Cnudde
--
-- Create Date: 17/01/2021
-- Design Name:
-- Module Name: ntt_control
-- Project Name:
-- Description:
--
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--    TODO:
--      1. Implementation has dead cycles (i.e. m, i, j are incremented in separate states)
--      2.
--      3.
--
-- -------------------------------------------------------------------------- --
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ntt_control is
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
end entity;

architecture rtl of ntt_control is

  signal m_reg, m_next : std_logic_vector(n_width-1 downto 0);
  signal t_reg, t_next : std_logic_vector(n_width-1 downto 0);
  signal i_reg, i_next : std_logic_vector(n_width-2 downto 0);
  signal j_reg, j_next : std_logic_vector((n_width)+(n_width-1) downto 0);
  signal j1_reg, j1_next : std_logic_vector((n_width)+(n_width-1) downto 0);
  signal j2_reg, j2_next : std_logic_vector((n_width)+(n_width-1) downto 0);
  signal S_reg, S_next : std_logic_vector(data_width-1 downto 0);
  signal V : unsigned(2*data_width-1 downto 0);
  signal h_reg, h_next : std_logic_vector(n_width-1 downto 0);

  type state_type is (IDLE_STATE, INCREMENT_M, DECREMENT_M, INCREMENT_I, INCREMENT_J, SCALE_STATE, DONE_STATE);
  signal state_reg, state_next : state_type;

begin

  m <= m_reg;
  t <= t_reg;
  i <= i_reg;
  j <= j_reg;
  h <= h_reg;

  process(clk)
  begin
    if rst='1' then
      t_reg <= (others => '0');
      m_reg <= (others => '0');
      i_reg <= (others => '0');
      j_reg <= (others => '0');
      j1_reg <= (others => '0');
      j2_reg <= (others => '0');
      S_reg <= (others => '0');
      h_reg <= (others => '0');
      state_reg <= IDLE_STATE;
    elsif rising_edge(clk) then
      t_reg <= t_next;
      m_reg <= m_next;
      i_reg <= i_next;
      j_reg <= j_next;
      j1_reg <= j1_next;
      j2_reg <= j2_next;
      S_reg <= S_next;
      h_reg <= h_next;
      state_reg <= state_next;
    end if;
  end process;

  FSM : process(state_reg, start, t_reg, m_reg, i_reg, j_reg, j1_reg, j2_reg, S_reg, h_reg) --, phi, a_j, a_j_t)
  begin
    -- Default assignations to avoid latches
    state_next <= state_reg;
    done <= '0';
    t_next <= t_reg;
    m_next <= m_reg;
    i_next <= i_reg;
    j_next <= j_reg;
    j1_next <= j1_reg;
    j2_next <= j2_reg;
    S_next <= S_reg;
    h_next <= h_reg;

    case( state_reg ) is

      when IDLE_STATE =>
        if start='1' and fwd_bwd='0' then
          state_next <= INCREMENT_M;
          t_next <= std_logic_vector(to_unsigned(n, n_width));
          m_next <= std_logic_vector(to_unsigned(1, n_width));
        elsif start='1' and fwd_bwd='1' then
          state_next <= DECREMENT_M;
          t_next <= std_logic_vector(to_unsigned(1, n_width));
          m_next <= std_logic_vector(to_unsigned(n, n_width));
        end if;

      when INCREMENT_M =>
        -- t = t/2
        t_next <= '0' & t_reg(n_width-1 downto 1);
        -- Init i_reg
        i_next <= (others => '0');
        -- Always go to INCREMENT_I
        state_next <= INCREMENT_I;

      when INCREMENT_I =>
        if fwd_bwd='0' then
          j1_next <= std_logic_vector(unsigned(i_reg) * unsigned(t_reg)) & '0'; -- 2 * i * t
          --j2_next <= std_logic_vector(unsigned(j1_next) + unsigned(t_reg) - 1);
          j2_next <= std_logic_vector( unsigned(std_logic_vector(unsigned(i_reg) * unsigned(t_reg)) & '0') + unsigned(t_reg) - 1);
          -- Init j_reg
          --j_next <= j1_next;
          j_next <= std_logic_vector(unsigned(i_reg) * unsigned(t_reg)) & '0';
        elsif fwd_bwd='1' then
          j2_next <= std_logic_vector(unsigned(j1_reg) + unsigned(t_reg) - 1);
          j_next <= j1_reg;
        end if;
        -- Always go to INCREMENT_J
        state_next <= INCREMENT_J;

      when INCREMENT_J =>
        if fwd_bwd='0' then
          -- U, V, a ...
          --V <= (unsigned(S_reg)*unsigned(a_j_t) mod q);
          --a_j_out <= std_logic_vector(unsigned(a_j) + V(data_width-1 downto 0));
          --a_j_t_out <= std_logic_vector(unsigned(a_j) - V(data_width-1 downto 0));
          -- Increment & Check M if j is in last cycle
          -- for (m = 1; m < n; m = 2m)
          if j_reg=j2_reg and unsigned(i_reg)=(unsigned(m_reg)-1) and m_reg(n_width-2)='1' then
            state_next <= DONE_STATE;
          -- for (i=0; i<m; i++)
          elsif j_reg=j2_reg and unsigned(i_reg)=(unsigned(m_reg)-1) then
            m_next <= m_reg(n_width-2 downto 0) & '0';
            state_next <= INCREMENT_M;
          -- for (j=j1; j \leq j2; j++)
          elsif j_reg=j2_reg then
            i_next <= std_logic_vector(unsigned(i_reg) + 1);
            state_next <= INCREMENT_I;
          else
            -- Increment J
            j_next <= std_logic_vector(unsigned(j_reg) + 1);
          end if;

        elsif fwd_bwd='1' then
          -- U, V, a ...
          --V <= (unsigned(S_reg)*(unsigned(a_j) - unsigned(a_j_t)) mod q);
          --a_j_out <= std_logic_vector(unsigned(a_j) + unsigned(a_j_t));
          --a_j_t_out <= std_logic_vector(V(data_width-1 downto 0));
          if j_reg=j2_reg and unsigned(i_reg)=(unsigned(h_reg)-1) and m_reg(1)='1' then
            j_next <= (others => '0');
            state_next <= SCALE_STATE;
          elsif j_reg=j2_reg and unsigned(i_reg)=(unsigned(h_reg)-1) then
            m_next <= '0' & m_reg(n_width-1 downto 1);
            t_next <= t_reg(n_width-2 downto 0) & '0';
            state_next <= DECREMENT_M;
          elsif j_reg=j2_reg then
            j1_next <= std_logic_vector(unsigned(j1_reg) + 2*unsigned(t_reg));
            i_next <= std_logic_vector(unsigned(i_reg) + 1);
            state_next <= INCREMENT_I;
          else
            -- Increment J
            j_next <= std_logic_vector(unsigned(j_reg) + 1);
          end if;
        end if;

      when DECREMENT_M =>
        j1_next <= (others => '0');
        h_next <= '0' & m_reg(n_width-1 downto 1);
        -- Init i_reg
        i_next <= (others => '0');
        -- Always go to INCREMENT_I
        state_next <= INCREMENT_I;

      when DONE_STATE =>
        done <= '1';
        state_next <= IDLE_STATE;

      when SCALE_STATE =>
        if to_integer(unsigned(j_reg))=(n-1) then
          state_next <= DONE_STATE;
        else
          --V <= (unsigned(a_j)*to_unsigned(n_inv, data_width) mod q);
          --a_j_out <= std_logic_vector(V(data_width-1 downto 0));
          j_next <= std_logic_vector(unsigned(j_reg) + 1);
        end if;

      when others =>
        state_next <= IDLE_STATE;

    end case;
  end process;

end architecture;
