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
    start : in std_logic; -- __TODO__ not used, delete
    instruction : in std_logic_vector(5 downto 0);
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

  component rom_phi is
    port(
      address : in std_logic_vector(2 downto 0);
      dout : out std_logic_vector(9 downto 0)
    );
  end component;

  component rom_phi_inv is
    port(
      address : in std_logic_vector(2 downto 0);
      dout : out std_logic_vector(9 downto 0)
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

  component add_mod is
    generic (data_width : integer; q : integer);
    port (
      -- Inputs
      clk : in std_logic;
      a, b : in std_logic_vector(data_width-1 downto 0);
      -- Outputs
      c : out std_logic_vector(data_width-1 downto 0)
    );
  end component;

  component sub_mod is
    generic (data_width : integer; q : integer);
    port (
      -- Inputs
      clk : in std_logic;
      a, b : in std_logic_vector(data_width-1 downto 0);
      -- Outputs
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
      break : in std_logic; -- pause if '1', continue if '0'
      fwd_bwd : in std_logic; -- 0: fwd, 1: bwd
      -- Outputs
      valid : out std_logic;
      m_plus_i_valid, h_plus_i_valid : out std_logic;
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
  signal break_counter_reg, break_counter_next : std_logic_vector(3 downto 0); --__TODO__ Change width dyn
  signal a1_wr_reg, a1_wr_next, a2_wr_reg, a2_wr_next : std_logic;
  signal a_addr_reg, a_addr_next, b_addr_reg, b_addr_next : std_logic_vector(addr-1 downto 0);
  signal a_din1, a_din2, b_dout1, b_dout2 : std_logic_vector(data_width-1 downto 0);

  signal m_plus_i, h_plus_i : std_logic_vector(n_width downto 0); -- Lenght: n_width + 1
  signal phi_addr, phi_inv_addr : std_logic_vector(2 downto 0);
  signal phi_out, phi_inv_out : std_logic_vector(data_width-1 downto 0);
  signal S_reg, S_next : std_logic_vector(data_width-1 downto 0);
  signal U_reg, U_next, V_reg, V_next : std_logic_vector(data_width-1 downto 0);

  signal mult_in1_reg, mult_in1_next : std_logic_vector(data_width-1 downto 0);
  signal mult_in2_reg, mult_in2_next : std_logic_vector(data_width-1 downto 0);
  signal mult_out : std_logic_vector(data_width-1 downto 0);

  signal add_in1_reg, add_in1_next : std_logic_vector(data_width-1 downto 0);
  signal add_in2_reg, add_in2_next : std_logic_vector(data_width-1 downto 0);
  signal add_out : std_logic_vector(data_width-1 downto 0);
  signal sub_in1_reg, sub_in1_next : std_logic_vector(data_width-1 downto 0);
  signal sub_in2_reg, sub_in2_next : std_logic_vector(data_width-1 downto 0);
  signal sub_out : std_logic_vector(data_width-1 downto 0);

  signal fwd_bwd_reg, fwd_bwd_next : std_logic;
  signal ntt_start, ntt_break, ntt_done : std_logic;

  signal valid, m_plus_i_valid, h_plus_i_valid : std_logic;

  signal m : std_logic_vector(n_width-1 downto 0);
  signal t : std_logic_vector(n_width-1 downto 0);
  signal i : std_logic_vector(n_width-2 downto 0);
  signal j : std_logic_vector((n_width)+(n_width-1) downto 0);
  signal h : std_logic_vector(n_width-1 downto 0);

  type state_type is (IDLE_STATE, LOAD_STATE, CMULT_STATE, FNTT_STATE, BNTT_STATE, SCALE_STATE, READ_STATE, DONE_STATE);
  signal state_reg, state_next : state_type;

begin

  data_out1 <= b_dout1; -- __TODO__ when read_state_mux else
  data_out2 <= b_dout2; -- __TODO__ when read_state_mux else

  ram_memory_a : bram_tdp
  generic map(data => data_width, addr => addr)
  port map(
    a_clk => clk,
    a_wr => a1_wr_reg,
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
    a_wr => a2_wr_reg,
    a_addr => a_addr_reg,
    a_din => a_din2,
    a_dout => open,
    -- Port B
    b_clk => clk,
    b_wr => '0',
    b_addr => b_addr_reg,
    b_din => (others => '0'),
    b_dout => b_dout2 );

  m_plus_i <= std_logic_vector(to_unsigned(to_integer(unsigned(m))+to_integer(unsigned(i)), n_width+1));
  phi_addr <= m_plus_i(2 downto 0);
  phi: rom_phi port map(address => phi_addr, dout => phi_out);

  h_plus_i <= std_logic_vector(to_unsigned(to_integer(unsigned(h))+to_integer(unsigned(i)), n_width+1));
  phi_inv_addr <= h_plus_i(2 downto 0);
  phi_inv: rom_phi_inv port map(address => phi_inv_addr, dout => phi_inv_out);

  S_next <= phi_out when m_plus_i_valid='1' else
            phi_inv_out when h_plus_i_valid='1' else S_reg; -- __TODO__ Signals overlap so can be unified

  mult: multiplier generic map(data_width => data_width, q => q)
  port map(clk => clk, a => mult_in1_reg, b => mult_in2_reg, c => mult_out);

  add: add_mod generic map(data_width => data_width, q => q)
  port map(clk => clk, a => add_in1_reg, b => add_in2_reg, c => add_out);

  sub: sub_mod generic map(data_width => data_width, q => q)
  port map(clk => clk, a => sub_in1_reg, b => sub_in2_reg, c => sub_out);

  ntt_controler: ntt_control
    generic map ( n => n, n_inv => n_inv, q => q, data_width => data_width, n_width => n_width )
    port map (
      clk => clk, rst => rst, start => ntt_start, break => ntt_break, fwd_bwd => fwd_bwd_reg,
      valid => valid, m_plus_i_valid => m_plus_i_valid, h_plus_i_valid => h_plus_i_valid,
      m => m, t => t, i => i, j => j, h => h,
      done => ntt_done );

  process(clk)
  begin
    if rst='1' then
      n_counter_reg <= (others => '0');
      state_reg <= IDLE_STATE;
      a1_wr_reg <= '0';
      a2_wr_reg <= '0';
      a_addr_reg <= (others => '0');
      b_addr_reg <= (others => '0');
      mult_in1_reg <= (others => '0');
      mult_in2_reg <= (others => '0');
      mult_counter_reg <= (others => '0');
      fwd_bwd_reg <= '0';
      S_reg <= (others => '0');
      U_reg <= (others => '0');
      V_reg <= (others => '0'); -- __TODO__ V_reg never used...
      add_in1_reg <= (others => '0');
      add_in2_reg <= (others => '0');
      sub_in1_reg <= (others => '0');
      sub_in2_reg <= (others => '0');
      break_counter_reg <= (others => '0');
    elsif rising_edge(clk) then
      n_counter_reg <= n_counter_next;
      state_reg <= state_next;
      a1_wr_reg <= a1_wr_next;
      a2_wr_reg <= a2_wr_next;
      a_addr_reg <= a_addr_next;
      b_addr_reg <= b_addr_next;
      mult_in1_reg <= mult_in1_next;
      mult_in2_reg <= mult_in2_next;
      mult_counter_reg <= mult_counter_next;
      fwd_bwd_reg <= fwd_bwd_next;
      S_reg <= S_next;
      U_reg <= U_next;
      V_reg <= V_next;
      add_in1_reg <= add_in1_next;
      add_in2_reg <= add_in2_next;
      sub_in1_reg <= sub_in1_next;
      sub_in2_reg <= sub_in2_next;
      break_counter_reg <= break_counter_next;
    end if;
  end process;

  FSM : process(state_reg, instruction, n_counter_reg, a1_wr_reg, a2_wr_reg, a_addr_reg, b_addr_reg, mult_in1_reg, mult_in2_reg, mult_counter_reg, data_in1, data_in2, mult_out, fwd_bwd_reg, ntt_done, j, t, valid, break_counter_reg, S_reg, U_reg, V_reg, add_in1_reg, add_in2_reg, add_out, sub_in1_reg, sub_in2_reg, sub_out)
  begin
    -- Default assignations to avoid latches
    state_next <= state_reg;
    n_counter_next <= n_counter_reg;
    a1_wr_next <= a1_wr_reg;
    a2_wr_next <= a2_wr_reg;
    a_addr_next <= a_addr_reg;
    b_addr_next <= b_addr_reg;
    mult_in1_next <= mult_in1_reg;
    mult_in2_next <= mult_in2_reg;
    mult_counter_next <= mult_counter_reg;
    fwd_bwd_next <= fwd_bwd_reg;
    break_counter_next <= break_counter_reg;
    U_next <= U_reg;
    V_next <= V_reg;
    add_in1_next <= add_in1_reg;
    add_in2_next <= add_in2_reg;
    sub_in1_next <= sub_in1_reg;
    sub_in2_next <= sub_in2_reg;

    a_din1 <= (others => '0');
    a_din2 <= (others => '0');
    ntt_start <= '0';
    ntt_break <= '0';
    done <= '0';

    case( state_reg ) is
      when IDLE_STATE =>
        if instruction(4 downto 0)="00001" then -- LOAD
          n_counter_next <= (others => '0');
          a1_wr_next <= '1';
          a2_wr_next <= '1';
          a_addr_next <= (others => '0');
          state_next <= LOAD_STATE;
        elsif instruction(4 downto 0)="00010" then -- READ
          n_counter_next <= (others => '0');
          b_addr_next <= (others => '0');
          state_next <= READ_STATE;
        elsif instruction(4 downto 0)="00100" then
          mult_counter_next <= (others => '0');
          b_addr_next <= (others => '0');
          state_next <= CMULT_STATE;
        elsif instruction(4 downto 0)="01000" then
          state_next <= FNTT_STATE;
          fwd_bwd_next <= '0';
        elsif instruction(4 downto 0)="10000" then
          state_next <= BNTT_STATE;
          fwd_bwd_next <= '1';
        end if;

      when LOAD_STATE =>
        a_din1 <= data_in1;
        a_din2 <= data_in2;
        if to_integer(unsigned(n_counter_reg))=n-1 then
          state_next <= DONE_STATE;
          a1_wr_next <= '0';
          a2_wr_next <= '0';
          a_addr_next <= (others => '0');
        else
          n_counter_next <= std_logic_vector(unsigned(n_counter_reg) + 1);
          a1_wr_next <= '1';
          a2_wr_next <= '1';
          a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
        end if;

      when CMULT_STATE =>
        if to_integer(unsigned(mult_counter_reg))=n-1+1+1+1 then -- +1 for mult input regs, +1 for mult regs + 1 for write to ram
          state_next <= DONE_STATE;
          b_addr_next <= (others => '0');
          if instruction(5)='1' then
            a2_wr_next <= '0';
            a_din2 <= mult_out;
          else
            a1_wr_next <= '0';
            a_din1 <= mult_out;
          end if;
          a_addr_next <= (others => '0');
        elsif to_integer(unsigned(mult_counter_reg))>=n-1 then
          mult_counter_next <= std_logic_vector(unsigned(mult_counter_reg) + 1);
          b_addr_next <= (others => '0');
          mult_in1_next <= b_dout1;
          mult_in2_next <= b_dout2;
          if instruction(5)='1' then
            -- write to ram b
            a2_wr_next <= '1';
            a_din2 <= mult_out;
          else
            -- write to ram a
            a1_wr_next <= '1';
            a_din1 <= mult_out;
          end if;
          a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
        else
          if to_integer(unsigned(b_addr_reg))=1+1 then
            if instruction(5)='1' then
              -- write to ram b
              a2_wr_next <= '1';
            else
              -- write to ram a
              a1_wr_next <= '1';
            end if;
            a_addr_next <= (others => '0');
          elsif to_integer(unsigned(b_addr_reg))>1+1 then
            if instruction(5)='1' then
              a2_wr_next <= '1';
              a_din2 <= mult_out;
            else
              a1_wr_next <= '1';
              a_din1 <= mult_out;
            end if;
            a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
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
          if valid='1' then
            if to_integer(unsigned(break_counter_reg))=12 then -- __TODO__ dyn
              ntt_break <= '0';
              break_counter_next <= (others => '0');
            else
              ntt_break <= '1';
              break_counter_next <= std_logic_vector(unsigned(break_counter_reg) + 1);
              if to_integer(unsigned(break_counter_reg))=0 then
                b_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j))+to_integer(unsigned(t)), addr));
              elsif to_integer(unsigned(break_counter_reg))=2 then
                b_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j)), addr));
              elsif to_integer(unsigned(break_counter_reg))=3 then
                -- __TODO__ Reset b_addr?
                if instruction(5)='1' then
                  mult_in1_next <= b_dout2;
                else
                  mult_in1_next <= b_dout1;
                end if;
                mult_in2_next <= S_reg; -- __TODO__ S_reg can probably go ...
              elsif to_integer(unsigned(break_counter_reg))=4 then
                if instruction(5)='1' then
                  U_next <= b_dout2;
                else
                  U_next <= b_dout1;
                end if;
              elsif to_integer(unsigned(break_counter_reg))=5 then
                -- mult_out ready, Butterfly operation
                add_in1_next <= U_reg;
                add_in2_next <= mult_out;
                sub_in1_next <= U_reg;
                sub_in2_next <= mult_out;
              elsif to_integer(unsigned(break_counter_reg))=7 then
                -- Prepare Store a[j] <= add_out
                if instruction(5)='1' then
                  a2_wr_next <= '1';
                else
                  a1_wr_next <= '1';
                end if;
                a_addr_next <= j(addr-1 downto 0);
              elsif to_integer(unsigned(break_counter_reg))=8 then
                -- Store a[j] <= add_out
                -- Prepare Store a[j+t] <= sub_out
                if instruction(5)='1' then
                  a2_wr_next <= '1';
                  a_din2 <= add_out;
                else
                  a1_wr_next <= '1';
                  a_din1 <= add_out;
                end if;
                a_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j))+to_integer(unsigned(t)), addr));
              elsif to_integer(unsigned(break_counter_reg))=9 then
                -- Store a[j+t] <= sub_out
                if instruction(5)='1' then
                  a2_wr_next <= '0';
                  a_din2 <= sub_out;
                else
                  a1_wr_next <= '0';
                  a_din1 <= sub_out;
                end if;
              end if;
            end if;
          end if;
        end if;

      when BNTT_STATE =>
        if ntt_done='1' then
          state_next <= SCALE_STATE;
          ntt_start <= '0';
          -- Init for Scaling
          mult_counter_next <= (others => '0');
          b_addr_next <= (others => '0');
        else
          ntt_start <= '1';
          if valid='1' then
            if to_integer(unsigned(break_counter_reg))=12 then -- __TODO__ dyn
              ntt_break <= '0';
              break_counter_next <= (others => '0');
            else
              ntt_break <= '1';
              break_counter_next <= std_logic_vector(unsigned(break_counter_reg) + 1);
              if to_integer(unsigned(break_counter_reg))=0 then
                b_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j)), addr));
              elsif to_integer(unsigned(break_counter_reg))=1 then
                b_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j))+to_integer(unsigned(t)), addr));
              elsif to_integer(unsigned(break_counter_reg))=2 then
                if instruction(5)='1' then
                  U_next <= b_dout2;
                else
                  U_next <= b_dout1;
                end if;
              elsif to_integer(unsigned(break_counter_reg))=3 then
                -- Add U + b_dout1
                add_in1_next <= U_reg; -- __TODO REGs store the same data in both NTTs, can be collapsed...
                sub_in1_next <= U_reg;
                if instruction(5)='1' then
                  add_in2_next <= b_dout2;
                  sub_in2_next <= b_dout2;
                else
                  add_in2_next <= b_dout1;
                  sub_in2_next <= b_dout1;
                end if;
              elsif to_integer(unsigned(break_counter_reg))=4 then
                -- Addition & Subtraction Inputs Registered
                -- Prepare Store a[j] <= add_out
                if instruction(5)='1' then
                  a2_wr_next <= '1';
                else
                  a1_wr_next <= '1';
                end if;
                a_addr_next <= j(addr-1 downto 0);
              elsif to_integer(unsigned(break_counter_reg))=5 then
                -- Addition & Subtraction Ready
                -- Store a[j] <= add_out
                if instruction(5)='1' then
                  a2_wr_next <= '0';
                  a_din2 <= add_out;
                else
                  a1_wr_next <= '0';
                  a_din1 <= add_out;
                end if;
                -- Send Subtraction Result to Multiplier
                mult_in1_next <= sub_out;
                mult_in2_next <= S_reg; -- __TODO__ S_reg can probably go ...
              elsif to_integer(unsigned(break_counter_reg))=6 then
                -- Multiplier Inputs Registered
                -- Prepare Store a[j+t] <= mult_out
                if instruction(5)='1' then
                  a2_wr_next <= '1';
                else
                  a1_wr_next <= '1';
                end if;
                a_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(j))+to_integer(unsigned(t)), addr));
              elsif to_integer(unsigned(break_counter_reg))=7 then
                -- Multiplication Ready
                -- Store a[j+t] <= mult_out
                if instruction(5)='1' then
                  a2_wr_next <= '0';
                  a_din2 <= mult_out;
                else
                  a1_wr_next <= '0';
                  a_din1 <= mult_out;
                end if;
              end if;
            end if;
          end if;
        end if;

      when SCALE_STATE =>
        if to_integer(unsigned(mult_counter_reg))=n-1+1+1+1 then -- +1 for mult input regs, +1 for mult regs + 1 for write to ram
          state_next <= DONE_STATE;
          b_addr_next <= (others => '0');
          a_addr_next <= (others => '0');
          if instruction(5)='1' then
            a2_wr_next <= '0';
            a_din2 <= mult_out;
          else
            a1_wr_next <= '0';
            a_din1 <= mult_out;
          end if;
        elsif to_integer(unsigned(mult_counter_reg))>=n-1 then
          mult_counter_next <= std_logic_vector(unsigned(mult_counter_reg) + 1);
          b_addr_next <= (others => '0');
          if instruction(5)='1' then
            a2_wr_next <= '1';
            a_din2 <= mult_out;
            mult_in1_next <= b_dout2;
          else
            a1_wr_next <= '1';
            a_din1 <= mult_out;
            mult_in1_next <= b_dout1;
          end if;
          mult_in2_next <= std_logic_vector(to_unsigned(n_inv, data_width));
          a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
        else
          if to_integer(unsigned(b_addr_reg))=1+1 then
            if instruction(5)='1' then
              a2_wr_next <= '1';
            else
              a1_wr_next <= '1';
            end if;
            a_addr_next <= (others => '0');
          elsif to_integer(unsigned(b_addr_reg))>1+1 then
            a_addr_next <= std_logic_vector(unsigned(a_addr_reg) + 1);
            if instruction(5)='1' then
              a2_wr_next <= '1';
              a_din2 <= mult_out;
            else
              a1_wr_next <= '1';
              a_din1 <= mult_out;
            end if;
          end if;
          mult_counter_next <= std_logic_vector(unsigned(mult_counter_reg) + 1);
          b_addr_next <= std_logic_vector(unsigned(b_addr_reg) + 1);
          if instruction(5)='1' then
            mult_in1_next <= b_dout2;
          else
            mult_in1_next <= b_dout1;
          end if;
          mult_in2_next <= std_logic_vector(to_unsigned(n_inv, data_width));
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
