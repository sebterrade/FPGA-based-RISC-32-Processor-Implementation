-- ------------------------------------------------------
-- system.vhd: top-level entity incorporating an instance
-- of a processor and storage for code/data;
-- output signals allow for observation of operation
--
-- Naraig Manjikian
-- February 2012
-- ------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.my_components.all;
-- 'my_components' package has declarations for processor and 32-bit register

entity system is
  port (
    clk          : in std_logic;
    reset_n      : in std_logic;
    ifetch_out   : out std_logic;
    mem_addr_out : out std_logic_vector(31 downto 0);
    data_from_procr : out std_logic_vector(31 downto 0);
    data_to_procr : out std_logic_vector(31 downto 0);
    mem_read     : out std_logic;
    mem_write    : out std_logic
  );
end entity;

-- ------------------------------------------------------

architecture synth of system is

-- internal signals to model a memory
signal internal_addr : std_logic_vector(31 downto 0);
signal data_to_mem, data_from_mem : std_logic_vector(31 downto 0);
signal write_to_data_location : std_logic;
signal data_out : std_logic_vector(31 downto 0);
signal internal_write : std_logic;

-- define constant bit patterns for test instructions
-- .... SRC1       SRC2     IMM16                OPCODE .....

constant LOAD_R1  : std_logic_vector(31 downto 0)
	:= ("00000" & "00001" & "0001000000000000" & "010111");

constant STORE_R1 : std_logic_vector(31 downto 0)
	:= ("00000" & "00001" & "0001000000000000" & "010101");	  

constant ADDI_R1  : std_logic_vector(31 downto 0)
	:= ("00001" & "00001" & "0000000000000001" & "000100");	  

constant BR_START : std_logic_vector(31 downto 0)
	:= ("00000" & "00000" & "1111111111110000" & "000110");	  
-- offset of -4 words = -16 bytes = -1 - 15 = FFFF - F = FFF0
 
begin

-- instantiate processor, and associate various toplevel and internal signals
the_processor : processor
	port map (
		clk          => clk,
		reset_n      => reset_n,
		mem_addr_out => internal_addr,
		mem_data_out => data_to_mem,
		mem_data_in  => data_from_mem,
		mem_read     => mem_read,
		mem_write    => internal_write,
		ifetch_out   => ifetch_out
	);

-- assign remaining toplevel ports
data_from_procr <= data_to_mem;
mem_addr_out <= internal_addr;
mem_write <= internal_write;
data_to_procr <= data_from_mem;

-- instantiate register-based storage for one read/write location in memory
for_data: reg32 port map (clk, reset_n, write_to_data_location,
                          data_to_mem, data_out);

-- ensure that write operation performed only for correct address
-- (if more writable locations are added, check if address is in a range)
write_to_data_location <=   '1' when (internal_addr = X"00001000"
                                      and internal_write = '1')
                       else '0';
                       
-- model the full memory output for instruction and data addresses
data_from_mem <=   LOAD_R1  when (internal_addr = X"00000000")
              else ADDI_R1  when (internal_addr = X"00000004")   
              else STORE_R1 when (internal_addr = X"00000008")   
              else BR_START when (internal_addr = X"0000000c") 
              else data_out;   -- internal_addr = X"00001000")
                               -- (if more data locations added,
                               --  then more decoding is needed)

end architecture;
