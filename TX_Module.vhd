--------------------------------------------------------------------------------------------
--   State = 1: Disabled  '1' on the serial line 
--   State = 2: Start Bit '0' on the serial line
--   Other States= din(7 downto 0) on the serial line
--	  Interrupt (int) is raised for 1 clock cyle when stop bit is put into line
--------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TX_Module is
	 Generic (baud_rate: integer;
				 clk_freq: integer);
    Port ( clk : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           enable : in  STD_LOGIC;
			  int	 : out STD_LOGIC;
           dout : out  STD_LOGIC);
end TX_Module;

architecture Behavioral of TX_Module is
	
	COMPONENT Baud_Pulse_Generator
	GENERIC (baud_rate: integer;
				clk_freq: integer);
	PORT(clk : IN std_logic;
		enable : IN std_logic;
		baud_select : IN std_logic;          
		baud_pulse : OUT std_logic
		);
	END COMPONENT;

	--Internal signals
	signal state: integer range 1 to 10 := 1;
	
	signal baud_signal : STD_LOGIC := '0';
	signal baud_enable_signal  : STD_LOGIC := '0';
	signal din_buffer : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	
	--IO Signals
	signal din_signal : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	signal enable_signal : STD_LOGIC := '0';
	signal int_signal : STD_LOGIC := '0';
	signal dout_signal : STD_LOGIC := '1';
	
begin
	
	Pulse_Generator_TX: Baud_Pulse_Generator 
	GENERIC MAP(
		baud_rate => baud_rate,
		clk_freq => clk_freq
	)
	PORT MAP(
		clk => clk,
		baud_pulse => baud_signal,
		enable => baud_enable_signal,
		baud_select => '0'										-- We will always count 1 Baud in Tx
	);
	
	process(clk)
	begin
		if rising_edge(clk) then
			
			--Inputs of the module
			din_signal <= din;
			enable_signal <= enable;
			
			if enable_signal = '0' then
				
				state <= 1;										--State disabled
				int_signal <= '0';					
				dout_signal <= '1';							--Constant high to output
				baud_enable_signal <= '0';					--Shut down baud counter + reset it
			
			else
			
				baud_enable_signal <= '1';					--Open baud counter
				int_signal <= '0';
				
				if baud_signal = '1' then
					case state is
						when 1 => 
							state <= state + 1;
							din_buffer <= din_signal;							-- This will hold same value till the end of transmission
							int_signal <= '0';
							dout_signal <= '0';									-- We will moving into state 2, communication will start		
						when 10 =>
							state <= 1;												-- Go to beginning
							int_signal <= '1';
							dout_signal <= '1';									-- Stop bit on the line
						when others =>
							state <= state + 1;									-- Increment state
							int_signal <= '0';							
							dout_signal <= din_buffer(0);						-- Put the next data bit onto line (LSB first)
							din_buffer <= '0' & din_buffer(7 downto 1);
					end case;
				end if;
				
			end if;
			
			-- Outputs of the module
			dout <= dout_signal;
			int <= int_signal;
			
		end if;
	end process;
end Behavioral;