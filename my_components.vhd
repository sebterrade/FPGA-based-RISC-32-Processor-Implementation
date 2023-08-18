-- ------------------------------------------------------
-- Package file to provide component
-- declarations for use in design hierarchy
--
-- Sebastien Terrade
-- August 2023
-- ------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package my_components is

component reg32
  port (
    clk     : in std_logic;
    reset_n : in std_logic;
    en      : in std_logic;
    d       : in std_logic_vector(31 downto 0);
    q       : out std_logic_vector
  );
end component;

component processor
  port (
    clk          : in std_logic;
    reset_n      : in std_logic;
    mem_addr_out : out std_logic_vector(31 downto 0);
    mem_data_out : out std_logic_vector(31 downto 0);
    mem_data_in  : in  std_logic_vector(31 downto 0);
    mem_read     : out std_logic;
    mem_write    : out std_logic;
    ifetch_out   : out std_logic
  );
end component;

end package;
