library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom_phi is
  port(
    address : in std_logic_vector(2 downto 0);
    dout : out std_logic_vector(9 downto 0)
  );
end entity rom_phi;

architecture rtl of rom_phi is

    type memory_8_10 is array (0 to 7) of std_logic_vector(9 downto 0);
    constant rom_8_10 : memory_8_10 := (
      "0000000001",
      "1001100111",
      "0101000110",
      "1001100001",
      "0001010100",
      "1000000000",
      "0111010000",
      "0000001000" );

begin

  process(address)
  begin
      dout <= rom_8_10(to_integer(unsigned(address)));
  end process;

end architecture rtl;
