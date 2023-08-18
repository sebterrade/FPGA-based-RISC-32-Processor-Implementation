-- --------------------------------------------------
--	Code for a 32-bit processor
-- Implements the main RISK-style instructions
--	Machine encoding of instructions based on NIOS II

-- Sebastien Terrade
--	August 2023
-- --------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.my_components.all;

-- --------------------------------------------------

entity processor is
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
end entity;

-- --------------------------------------------------

architecture synthesis of processor is

-- Internal register output signals
signal PC_out, IR_out 			: std_logic_vector(31 downto 0);
signal PC_Temp_out    			: std_logic_vector(31 downto 0);
signal RA_out, RB_out, RM_out : std_logic_vector(31 downto 0);
signal RY_out, RZ_out 			: std_logic_vector(31 downto 0);

-- PC adder output signal
signal PC_adder_out   : std_logic_vector(31 downto 0);

-- ALU input and output signals
signal ALU_op  						: std_logic_vector(3 downto 0);
signal ALU_out 						: std_logic_vector(31 downto 0);
signal ALU_zero_out, ALU_neg_out : std_logic;

-- MUX output signals
signal MuxB_out   : std_logic_vector(31 downto 0);
signal MuxC_out   : std_logic_vector(4 downto 0);
signal MuxINC_out : std_logic_vector(31 downto 0);
signal MuxMA_out  : std_logic_vector(31 downto 0);
signal MuxPC_out  : std_logic_vector(31 downto 0);
signal MuxY_out   : std_logic_vector(31 downto 0);

-- Step counter output signals
signal T1, T2, T3, T4, T5 : std_logic;

-- Currently supported outputs from instruction decoder  
signal INS_addi, INS_br, INS_ldw, INS_stw, INS_call, INS_ret : std_logic;

-- Register file input and output signals (includes only register r0-r5)
signal Address_A, Address_B, Address_C : std_logic_vector(4 downto 0);
signal regfile_A_out, regfile_B_out    : std_logic_vector(31 downto 0);
signal RF_write : std_logic;

signal r1_write : std_logic;
signal r1_out   : std_logic_vector(31 downto 0);
signal r2_write : std_logic;
signal r2_out   : std_logic_vector(31 downto 0);
signal r3_write : std_logic;
signal r3_out   : std_logic_vector(31 downto 0);
signal r4_write : std_logic;
signal r4_out   : std_logic_vector(31 downto 0);
signal r5_write : std_logic;
signal r5_out   : std_logic_vector(31 downto 0);

-- Instruction register bit field signals
signal IR_opcode 	: std_logic_vector(5 downto 0);
signal IR_opxcode	: std_logic_vector(5 downto 0); -- unique to R-FORMAT instructions
signal IR_src1   	: std_logic_vector(4 downto 0);
signal IR_src2   	: std_logic_vector(4 downto 0);
signal IR_dest   	: std_logic_vector(4 downto 0);
signal IR_imm16  	: std_logic_vector(15 downto 0);

-- 32-bit immediate signal (generated from 16 immediate value in IR)
signal imm32  : std_logic_vector(31 downto 0);

-- MUX select signals 
signal B_select   : std_logic;  
signal C_select   : std_logic_vector(1 downto 0);
signal INC_select : std_logic;
signal MA_select  : std_logic;
signal PC_select  : std_logic;
signal Y_select   : std_logic_vector(1 downto 0);

-- Enable signals for needed registers
signal PC_en, PC_Temp_en : std_logic;
signal IR_en : std_logic;

-- --------------------------------------------------

begin

-- Instantiations and connections of registers (reg32)


	  PC : reg32 port map (clk, reset_n, PC_en, 		 MuxPC_out,     PC_out);
PC_Temp : reg32 port map (clk, reset_n, PC_Temp_en, PC_out, 	    PC_Temp_out);
	  IR : reg32 port map (clk, reset_n, IR_en, 		 mem_data_in,   IR_out);
	  RA : reg32 port map (clk, reset_n, '1', 		 regfile_A_out, RA_out);
	  RB : reg32 port map (clk, reset_n, '1', 		 regfile_B_out, RB_out);
	  RM : reg32 port map (clk, reset_n, '1', 		 RB_out,   	    RM_out);
	  RY : reg32 port map (clk, reset_n, '1', 		 MuxY_out,      RY_out);
	  RZ : reg32 port map (clk, reset_n, '1', 		 ALU_out,       RZ_out);
	  
-- Register file (currently only supports r0-r5)
r1 : reg32 port map (clk, reset_n, r1_write, RY_out, r1_out);
r2 : reg32 port map (clk, reset_n, r2_write, RY_out, r2_out);
r3 : reg32 port map (clk, reset_n, r3_write, RY_out, r3_out);
r4 : reg32 port map (clk, reset_n, r4_write, RY_out, r4_out);
r5 : reg32 port map (clk, reset_n, r5_write, RY_out, r5_out);

-- Register file inputs and outputs (currently only supports r0-r5)

regfile_A_out <= r1_out when (Address_A = "00001")
					else r2_out when (Address_A ="00010")
					else r3_out when (Address_A ="00011")
					else r4_out when (Address_A ="00100")
					else r5_out when (Address_A ="00101")
					else (others => '0'); --covers r0 case
					
regfile_B_out <= r1_out when (Address_B = "00001")
					else r2_out when (Address_B ="00010")
					else r3_out when (Address_B ="00011")
					else r4_out when (Address_B ="00100")
					else r5_out when (Address_B ="00101")
					else (others => '0'); --covers r0 case

r1_write <= '1' when (RF_write = '1' and Address_C = "00001")
					else '0';
					
r2_write <= '1' when (RF_write = '1' and Address_C = "00010")
					else '0';
					
r3_write <= '1' when (RF_write = '1' and Address_C = "00011")
					else '0';
					
r4_write <= '1' when (RF_write = '1' and Address_C = "00100")
					else '0';
					
r5_write <= '1' when (RF_write = '1' and Address_C = "00101")
					else '0';
					

Address_A <= IR_src1;
Address_B <= IR_src2;
Address_C <= MuxC_out;

-- Step counter process to reflect clock cycles where '1' rotates throught 5 flip-flops
step_counter: process(clk, reset_n)
begin
	if (reset_n = '0') then
		T1 <= '1'; T2 <= '0'; T3 <= '0'; T4 <= '0'; T5 <= '0';
	elsif (rising_edge(clk)) then
		T1 <= T5;  T2 <= T1;  T3 <= T2;  T4 <= T3;  T5 <= T4;
	end if;
end process;

-- ALU combinational logic behavior process
ALU : process(RA_out, MuxB_out, ALU_op)
begin 
	case ALU_op is
		when "0000" =>
			ALU_out <= RA_out + MuxB_out;
		when others =>
			ALU_out <= RA_out + MuxB_out;
	end case;
end process;


ALU_neg_out  <= ALU_out(31); -- the sign bit
ALU_zero_out <=   '1' when (ALU_out = "00000000000000000000000000000000")
             else '0';
				 
-- PC adder process
PC_adder : process (PC_out, MuxINC_out)
begin
	PC_adder_out <= PC_out + MuxINC_out;
end process;

-- Extend 16-bit imm to 32-bit value process
imm32_generator : process (IR_imm16)
variable i : integer;
begin
	imm32(15 downto 0) <= IR_imm16; -- lower bits are the same
	for i in 31 downto 16 loop
		imm32(i) <= IR_imm16(15);   -- upper bits are copy of sign bit
    end loop;
end process;


--MUX control inputs
MuxB_out 	<= imm32 when (B_select = '1')
					else RB_out;
				
MuxC_out 	<= IR_dest when (C_select = "01")
					else IR_src2; -- need to add support for calls

MuxINC_out 	<= imm32 when (INC_select = '1')
					else "00000000000000000000000000000100"; -- (4)
				
MuxMA_out 	<= PC_out when (MA_select = '1')
					else RZ_out;

MuxPC_out 	<= PC_adder_out when (PC_select = '1')
					else RA_out;
				
MuxY_out 	<= PC_Temp_out when (Y_select = "10")
					else mem_data_in when (Y_select = "01")
					else RZ_out;

-- Extraction of bit fields from IR
IR_src1    <= IR_out(31 downto 27);
IR_src2    <= IR_out(26 downto 22);
IR_dest    <= IR_out(21 downto 17);
IR_imm16   <= IR_out(21 downto 6);
IR_opcode  <= IR_out(5 downto 0);
IR_opxcode <= IR_out(16 downto 11);

-- Generate outputs from instruction opcode decoder
INS_addi  <= '1' when (IR_opcode = "000100") else '0';
INS_br    <= '1' when (IR_opcode = "000110") else '0';
INS_ldw   <= '1' when (IR_opcode = "010111") else '0';
INS_stw   <= '1' when (IR_opcode = "010101") else '0';
INS_call  <= '1' when (IR_opcode = "000000") else '0';
INS_ret 	 <= '1' when (IR_opcode = "111010" and IR_opxcode = "000110") else '0';


-- Generate memory control signals
mem_read  <= T1 or (T4 and INS_ldw);
mem_write <= T4 and INS_stw;

-- Generate MUX control signals
B_select 	<= '1' when (IR_opcode /= "111010") -- when instruction is in I-Format
					else '0';

C_select 	<= "10" when (INS_ret = '1')
					else "01" when (IR_opcode = "111010")
					else "00";

INC_select 	<= T3 and INS_br;

MA_select  	<= T1;

PC_select  	<= not INS_ret;

Y_select 	<= "10" when (T4 ='1' and INS_call = '1')
					else "01" when (T4 = '1' and INS_ldw = '1')
					else "00";

-- Generate enable signals
PC_en 		<= T1 or (T3 and (INS_call or INS_ret or INS_br));

PC_Temp_en 	<= T3;

IR_en			<= T1;

-- Select ALU operation currently only addition (needs update)
ALU_op <= "0000";

-- Output to memory
mem_addr_out <= MuxMA_out;
mem_data_out <= RM_out;

-- GPR file write access
RF_write <= T5 and (INS_ldw or INS_addi or INS_call);

-- Beginning of cycle marker
ifetch_out <= T1;

end architecture;