-- !!!!  Module generics (clk_freq, baud_rate) are under module constants title, enter them there

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART is
    Port ( tx_data : in  STD_LOGIC_VECTOR (7 downto 0);
           rx_data : out  STD_LOGIC_VECTOR (7 downto 0);
			  tx_pin  : out STD_LOGIC;
			  rx_pin  : in STD_LOGIC;
			  read_en : in  STD_LOGIC;
			  write_en : in  STD_LOGIC;
			  rx_empty : out  STD_LOGIC;
			  tx_full  : out  STD_LOGIC;
			  rx_full  : out STD_LOGIC;
           clk : in  STD_LOGIC);
end UART;

architecture Behavioral of UART is

	--------------------------  Sub Module Declarations ------------------------------------------
	
	COMPONENT RX_Module
	GENERIC (baud_rate: integer;
				clk_freq: integer);
	PORT(din : IN std_logic;
		clk : IN std_logic;          
		dout : OUT std_logic_vector(7 downto 0);
		int : OUT std_logic;
		enable : IN std_logic
		);
	END COMPONENT;
	
	COMPONENT TX_Module
	GENERIC (baud_rate: integer;
				clk_freq: integer);
	PORT(clk : IN std_logic;
		din : IN std_logic_vector(7 downto 0);
		enable : IN std_logic;          
		int : OUT std_logic;
		dout : OUT std_logic
		);
	END COMPONENT;
	
	COMPONENT FIFO_Memory_1K
	PORT (
		 clk : IN STD_LOGIC;
		 din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 wr_en : IN STD_LOGIC;
		 rd_en : IN STD_LOGIC;
		 dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		 full : OUT STD_LOGIC;
		 empty : OUT STD_LOGIC
		 );
	END COMPONENT;
	
	---------------------- Type Declarations ----------------------------------------------------
	
	type TX_DATA_ARRAY_TYPE is array (2 downto 0) of std_logic_vector(7 downto 0);
	
	---------------------- Module Constants  ----------------------------------------------------
	--Please enter module generics here
	constant clk_freq : integer := 100000000;
	constant baud_rate : integer := 921600;
	constant RESET_COUNTER_MAX : integer := clk_freq / 1000;
	
	---------------------  Signals  -------------------------------------------------------------
	signal parallel_data_between_fifo_txmod_signal : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	signal parallel_data_between_fifo_rxmod_signal : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	
	signal tx_fifo_ren_signal : STD_LOGIC := '0';
	signal rx_fifo_wen_signal : STD_LOGIC := '0';
	signal tx_fifo_wen_signal : STD_LOGIC := '0';
	signal rx_fifo_ren_signal : STD_LOGIC := '0';

	signal tx_enable_signal : STD_LOGIC := '0';
	signal init_enable_for_rx : STD_LOGIC := '0';
	
	signal tx_int_signal : STD_LOGIC := '0';
	signal rx_int_signal : STD_LOGIC := '0';
	
	signal tx_fifo_empty_signal : STD_LOGIC := '0';
	signal rx_fifo_empty_signal : STD_LOGIC := '0';
	signal tx_fifo_full_signal : STD_LOGIC := '0';
	signal rx_fifo_full_signal : STD_LOGIC := '0';
	
	--Extra buffer signals, they are used for snyc sampling and debouncing
	signal read_en_sync : STD_LOGIC_VECTOR(2 downto 0) := "000";
	signal rx_pin_sync : STD_LOGIC_VECTOR(2 downto 0) := "111";
	signal write_en_sync : STD_LOGIC_VECTOR(2 downto 0) := "000";
	signal tx_data_sync : TX_DATA_ARRAY_TYPE;
	
	--Used for edge detection
	signal read_en_prev : STD_LOGIC := '0';
	signal write_en_prev : STD_LOGIC := '0';
	
	signal rx_data_signal : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	signal tx_pin_signal : STD_LOGIC := '1'; 
	
	-- Reset counter on start
	signal reset_counter : integer range 1 to RESET_COUNTER_MAX := 1;	-- For initial reset time 0.001 s
	
	
begin

	--------------------------  Sub Module Instants ---------------------------------------------
	Receiver: RX_Module
	GENERIC MAP(
		baud_rate => baud_rate,
		clk_freq => clk_freq
	)
	PORT MAP(
		din => rx_pin_sync(2),
		dout => parallel_data_between_fifo_rxmod_signal,
		clk => clk,
		int => rx_int_signal,
		enable => init_enable_for_rx
	);
	
	Transmitter: TX_Module
	GENERIC MAP(
		baud_rate => baud_rate,
		clk_freq => clk_freq
	)
	PORT MAP(
		clk => clk,
		din => parallel_data_between_fifo_txmod_signal,
		enable => tx_enable_signal,
		int => tx_int_signal,
		dout => tx_pin_signal
	);
	
   TX_Fifo : FIFO_Memory_1K PORT MAP (
     clk => clk,
     din => tx_data_sync(2),
     wr_en => tx_fifo_wen_signal,
     rd_en => tx_fifo_ren_signal,
     dout => parallel_data_between_fifo_txmod_signal,
     full => tx_fifo_full_signal,
     empty => tx_fifo_empty_signal
   );
	
	RX_Fifo : FIFO_Memory_1K PORT MAP (
     clk => clk,
     din => parallel_data_between_fifo_rxmod_signal,
     wr_en => rx_fifo_wen_signal,
     rd_en => rx_fifo_ren_signal,
     dout => rx_data_signal,
     full => rx_fifo_full_signal,
     empty => rx_fifo_empty_signal
   );
	--------------------------------------------------------------------------------------
	
	process(clk) 
	begin
		if rising_edge(clk) then
			
			if reset_counter = RESET_COUNTER_MAX then
				init_enable_for_rx <= '1';
			else
				reset_counter <= reset_counter + 1 ;
			end if;
			
			--Sample inputs from outside of the module
			--Debouncing code for these 4 signals
			read_en_sync(1) 	<= read_en_sync(0);
			rx_pin_sync(1)	 	<= rx_pin_sync(0);
			write_en_sync(1) 	<= write_en_sync(0);
			tx_data_sync(1) 	<= tx_data_sync(0);
			
			read_en_sync(0) 	<= read_en;
			rx_pin_sync(0)	 	<= rx_pin;
			write_en_sync(0) 	<= write_en;
			tx_data_sync(0) 	<= tx_data;

			if read_en_sync(1) = read_en_sync(0) then
				read_en_sync(2) <= read_en_sync(1);
			end if;
			
			if rx_pin_sync(1) = rx_pin_sync(0) then
				rx_pin_sync(2) <= rx_pin_sync(1);
			end if;
			
			if write_en_sync(1) = write_en_sync(0) then
				write_en_sync(2) <= write_en_sync(1);
			end if;

			if tx_data_sync(1) = tx_data_sync(0) then
				tx_data_sync(2) <= tx_data_sync(1);
			end if;
			
			--Transmitter requests next element
			if tx_int_signal = '1' then
				tx_fifo_ren_signal <= '1';
			else
				tx_fifo_ren_signal <= '0';
			end if;
			
			--First time we do this manually
			if tx_fifo_empty_signal = '0' and tx_enable_signal = '0' then
				tx_fifo_ren_signal <= '1';
			end if;
			
			--Receiver requests data to be read by FIFO 
			if rx_int_signal = '1' then
				rx_fifo_wen_signal <= '1';
			else
				rx_fifo_wen_signal <= '0';
			end if;
			
			if tx_fifo_empty_signal = '1' and tx_int_signal = '1' then
				--If FIFO is empty and last data is transmittted, disable transmission
				tx_enable_signal <= '0';
			elsif tx_fifo_empty_signal = '0' then
				--Enable transmission if there is something in transmit buffer
				tx_enable_signal <= '1';
			end if;
			
			--Read enable rising edge detection
			if read_en_prev = '0' and read_en_sync(2) = '1' then
				rx_fifo_ren_signal <= '1';
			else
				rx_fifo_ren_signal <= '0';
			end if;
			
			--Save sample for next operation
			read_en_prev <= read_en_sync(2);
			
			--Write enable rising edge detection
			if write_en_prev = '0' and write_en_sync(2) = '1' then
				tx_fifo_wen_signal <= '1';
			else
				tx_fifo_wen_signal <= '0';
			end if;
			
			--Save sample for next operation
			write_en_prev <= write_en_sync(2);
			
			--Outputs of the module
			tx_full <= tx_fifo_full_signal;
			rx_empty <= rx_fifo_empty_signal;
			rx_full <= rx_fifo_full_signal;
			rx_data <= rx_data_signal;
			tx_pin <= tx_pin_signal;
			
		end if;
	end process;
end Behavioral;