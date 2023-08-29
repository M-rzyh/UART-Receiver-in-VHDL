--Marziyeh Ghayour 98242112 - Bahar Moadeli 98242138

library ieee;
use ieee.std_logic_1164.ALL;
--use ieee.numeric_std.all;

-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 25 MHz Clock, 115200 baud UART
-- (25000000)/(115200) = 217

entity UART_RX is
  generic (
		g_Freq_i_Clk   : integer := 25000000; --fpga frequency
		g_Freq_UART    : integer := 115200;   --baud rate
		g_CLKS_PER_BIT : integer := 217       -- Freq_i_Clk/Freq_UART    
		);
  port (
    i_Clk        : in  std_logic;
	 i_Reset      : in std_logic;
    i_RX_Serial  : in  std_logic;                    --one bit of serial at a time
    o_RX_Valid   : out std_logic;                    --all 8 bits have benn recieved
    o_RX_Byte    : out std_logic_vector(7 downto 0)  --parallelized serial bits
    );
end UART_RX;


architecture RTL of UART_RX is

  type t_State is (s_Idle, s_RX_Start_Bit, s_RX_Data_Bits,
                     s_RX_Stop_Bit, s_Cleanup);
  signal r_Next_State, r_Reg_State : t_State := s_Idle;
  signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;         -- to count from 0 to g_CLKS_PER_BIT - 1 (0 to 216)
  signal r_Bit_Index : integer range 0 to 7 := 0;                        -- 8 Bits Total
  signal r_RX_Byte   : std_logic_vector(7 downto 0) := (others => '0');  --serial data will be saved parallelly
  signal r_RX_Valid  : std_logic := '0';                                 --valid output will be driven high for one clock cycle when data is completely recieved
  
begin
 --state register
process (i_Clk, i_Reset)
	begin
	if (i_Reset = '1') then
		r_Reg_State <= s_Idle;
	elsif (rising_edge(i_Clk)) then
		r_Reg_State <= r_Next_State;
	end if;
end process;
	
 --next state logic / output logic
process (r_Reg_State,i_RX_Serial,r_Clk_Count)
  begin
    if rising_edge(i_Clk) then
      
		case r_Next_State is

        when s_Idle =>
          r_RX_Valid     <= '0';
          r_Clk_Count <= 0;
          r_Bit_Index <= 0;

          if i_RX_Serial = '0' then       -- Start bit detected
            r_Next_State <= s_RX_Start_Bit;
          else
            r_Next_State <= s_Idle;
          end if;

          
        -- Check middle of start bit to make sure it's still low
        when s_RX_Start_Bit =>
          if r_Clk_Count = (g_CLKS_PER_BIT-1)/2 then
            if i_RX_Serial = '0' then
              r_Clk_Count <= 0;  -- reset counter since we found the middle
              r_Next_State   <= s_RX_Data_Bits;
            else
              r_Next_State   <= s_Idle;
            end if;
          else
            r_Clk_Count <= r_Clk_Count + 1;
            r_Next_State   <= s_RX_Start_Bit;
          end if;

          
        -- Wait g_CLKS_PER_BIT-1 clock cycles to sample serial data
        when s_RX_Data_Bits =>
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count    <= r_Clk_Count + 1;
            r_Next_State   <= s_RX_Data_Bits;
          else
            r_Clk_Count            <= 0;
            r_RX_Byte(r_Bit_Index) <= i_RX_Serial;
            
            -- Check if we have sent out all bits
            if r_Bit_Index < 7 then
              r_Bit_Index    <= r_Bit_Index + 1;
              r_Next_State   <= s_RX_Data_Bits;
            else
              r_Bit_Index    <= 0;
              r_Next_State   <= s_RX_Stop_Bit;
            end if;
          end if;


        -- Receive Stop bit.  Stop bit = 1
        when s_RX_Stop_Bit =>
          -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count    <= r_Clk_Count + 1;
            r_Next_State   <= s_RX_Stop_Bit;
          else
            r_RX_Valid     <= '1';
            r_Clk_Count    <= 0;
            r_Next_State   <= s_Cleanup;
          end if;

                  
        -- Stay here 1 clock
        when s_Cleanup =>
          r_Next_State <= s_Idle;
          r_RX_Valid   <= '0';

            
        when others =>
          r_Next_State <= s_Idle;
			 
      end case;
    end if;
  end process;

  o_RX_Valid   <= r_RX_Valid;
  o_RX_Byte    <= r_RX_Byte;
  
end RTL;
