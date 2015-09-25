library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Baud_Pulse_Generator is
	 Generic (clk_freq: integer;
				 baud_rate: integer);
    Port ( clk : in  STD_LOGIC;
           baud_pulse : out  STD_LOGIC;
           enable : in  STD_LOGIC;
			  baud_select : in STD_LOGIC 	-- 0 is 1 baud, 1 is 3/2 baud
			  );
end Baud_Pulse_Generator;

architecture Behavioral of Baud_Pulse_Generator is 
	 signal counter: integer range 1 to ((3*clk_freq)/2)/baud_rate := 1;
	 signal baud_pulse_signal : STD_LOGIC := '0';
	 signal enable_signal : STD_LOGIC := '0';
	 signal baud_select_signal : STD_LOGIC := '0';
begin
	 process(clk)
	 begin
	 
		 if rising_edge(clk) then
			
			--Inputs of the module
			enable_signal <= enable;
			baud_select_signal <= baud_select;
		
			if enable_signal = '1' then										
				counter <= counter + 1;
				if counter = (clk_freq/baud_rate) and  baud_select_signal = '0' then
					baud_pulse_signal <= '1';																	-- Send enable pulse
					counter <= 1;																					-- Reset counter to 0
				elsif counter = (((3*clk_freq)/2)/baud_rate) and  baud_select_signal = '1' then
					baud_pulse_signal <= '1';																	-- Send enable pulse
					counter <= 1;																					-- Reset counter to 0
				else
					baud_pulse_signal <= '0';								
				end if;
			else
				counter <= 1;
				baud_pulse_signal <= '0';
			end if;
			
			-- Outputs of the module
		   baud_pulse <= baud_pulse_signal;
			
		 end if;
		 
	 end process;
end Behavioral;