library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom_phi_inv is
  port(
    address : in std_logic_vector(2 downto 0);
    dout : out std_logic_vector(9 downto 0)
  );
end entity rom_phi_inv;

architecture rtl of rom_phi_inv is

    type memory_8_10 is array (0 to 7) of std_logic_vector(9 downto 0);
    constant rom_8_10 : memory_8_10 := (
      "0000000001",
      "0000111010",
      "0001000000",
      "0101011011",
      "1010011001",
      "0011010001",
      "0010100001",
      "1001001101" );

begin

  process(address)
  begin
      dout <= rom_8_10(to_integer(unsigned(address)));
  end process;

end architecture rtl;
