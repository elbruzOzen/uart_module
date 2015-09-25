----------------------------------------------------------------------------
-- First Low: Start Bit
-- After 8 Bit: Data
-- Last High: Stop Bit
-- Flag is raised during stop bit is received (state 10)
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity RX_Module is
	 Generic (clk_freq: integer;
				 baud_rate: integer);
    Port ( din : in  STD_LOGIC;
           dout : out  STD_LOGIC_VECTOR (7 downto 0);
           clk : in  STD_LOGIC;
           int : out  STD_LOGIC;
			  enable : in STD_LOGIC);
end RX_Module;

architecture Behavioral of RX_Module is
	
	COMPONENT Baud_Pulse_Generator
	GENERIC (clk_freq: integer;
				 baud_rate: integer);
	PORT(clk : IN std_logic;
		enable : IN std_logic;
		baud_select : IN std_logic;          
		baud_pulse : OUT std_logic
		);
	END COMPONENT;

	--Data Buffer will hold received data until receiving is finished
	--When this happens, it will write the value into data output
	signal state : integer range 1 to 10 := 1;
	signal data_buffer : STD_LOGIC_VECTOR (7 downto 0) := "00000000";
	signal baud_signal : STD_LOGIC := '0';
	signal baud_signal_from_generator : STD_LOGIC := '0';	-- This is for timing, I have pipelined this
	signal baud_enable_signal  : STD_LOGIC := '0';
	signal baud_select_signal  : STD_LOGIC := '0';
	
	-- IO Signals
	signal din_signal : STD_LOGIC := '1';
	signal dout_signal : STD_LOGIC_VECTOR (7 downto 0) := "00000000";
	signal int_signal : STD_LOGIC := '0';
	signal enable_signal : STD_LOGIC := '0';
	
	
begin
	
	Pulse_Generator_RX: Baud_Pulse_Generator 
	GENERIC MAP(
		baud_rate => baud_rate,
		clk_freq => clk_freq
	)
	PORT MAP(
		clk => clk,
		baud_pulse => baud_signal_from_generator,
		enable => baud_enable_signal,
		baud_select => baud_select_signal										
	);
	
	process(clk) 
	begin
		if rising_edge(clk) then
			
			-- Inputs of the module
			din_signal <= din;
			baud_signal <= baud_signal_from_generator;
			enable_signal <= enable;
			
			if enable_signal = '1' then
			
				case state is
					when 1 => 
							int_signal <= '0';
						if din_signal = '0' then											--First low is the start signal
							state <= 2;
							baud_enable_signal <= '1';
							baud_select_signal <= '1';										--Now we will wait 1.5 Baud before sampling
						end if;
					when 2 =>
						if baud_signal = '1' then
							state <= 3;			
							data_buffer <= din_signal & data_buffer(7 downto 1);
							baud_select_signal <= '0';										--After first there will be 1 baud between samples
						end if;
					when 10 =>
						if baud_signal = '1' then
							dout_signal <= data_buffer;									-- Write received data to output
							state <= 1;
							baud_enable_signal <= '0';
							int_signal <= '1';												--Raise interrupt flag					
						end if;
					when others =>
						if baud_signal = '1' then
							state <= state + 1;
							data_buffer <= din_signal & data_buffer(7 downto 1);
						end if;
				end case;
			
			else
				
				state <= 1;
				int_signal <= '0';
				baud_enable_signal <= '0';
				
			end if;
			
			-- Outputs of module
			dout <= dout_signal;
			int <= int_signal;
				
		end if;
	end process;
end Behavioral;