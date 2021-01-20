-- Temporary Multiplier --
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiplier is
  generic (data_width : integer; q : integer);
  port (
    -- Inputs
    clk : in std_logic;
    a, b : in std_logic_vector(data_width-1 downto 0);
    -- Outpus
    c : out std_logic_vector(data_width-1 downto 0)
  );
end entity;

architecture rtl of multiplier is

  signal p_reg, p_next : std_logic_vector(2*data_width-1 downto 0);

begin

  p_next <= std_logic_vector(to_unsigned(to_integer(unsigned(a)) * to_integer(unsigned(b)), 2*data_width)); --__TODO__ simplify

  c <= std_logic_vector(to_unsigned(to_integer(unsigned(p_reg)) mod q, data_width));

  process(clk)
  begin
    if rising_edge(clk) then
      p_reg <= p_next;
    end if;
  end process;

end architecture;
