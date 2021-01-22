library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sub_mod is
  generic (data_width : integer; q : integer);
  port (
    -- Inputs
    clk : in std_logic;
    a, b : in std_logic_vector(data_width-1 downto 0);
    -- Outputs
    c : out std_logic_vector(data_width-1 downto 0)
  );
end entity;

architecture rtl of sub_mod is

  signal w1_reg, w1_next : std_logic_vector(data_width downto 0);
  signal w2 : std_logic_vector(data_width-1 downto 0);

begin

  w1_next <= std_logic_vector(to_signed(to_integer(unsigned(a)) - to_integer(unsigned(b)), data_width+1));
  w2 <= std_logic_vector(unsigned(w1_reg(data_width-1 downto 0)) + q);
  c <= w2(data_width-1 downto 0) when w1_reg(data_width)='1' else w1_reg(data_width-1 downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
      w1_reg <= w1_next;
    end if;
  end process;

end architecture;
