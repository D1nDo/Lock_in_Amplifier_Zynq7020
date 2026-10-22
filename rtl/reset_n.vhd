library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Reset negativo dopo 16 cicli di clock
-- reset_n è generato da un registro su clk, quindi è sincrono a clk:
-- gli attributi X_INTERFACE lo dichiarano al block design (evita BD 41-1348)

entity reset_n is
    generic(
        REG_WIDTH : integer := 4
    );
    port(
        clk     : in  std_logic;
        reset_n : out std_logic := '0'
    );
end reset_n;

architecture Behavioral of reset_n is
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_INFO of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
    attribute X_INTERFACE_PARAMETER of clk : signal is "ASSOCIATED_RESET reset_n";
    attribute X_INTERFACE_INFO of reset_n : signal is "xilinx.com:signal:reset:1.0 reset_n RST";
    attribute X_INTERFACE_PARAMETER of reset_n : signal is "POLARITY ACTIVE_LOW";

    signal reg : unsigned(REG_WIDTH-1 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reg < (2**REG_WIDTH - 1) then
                reg <= reg + 1;
                reset_n <= '0';
            else
                reset_n <= '1';
            end if;
        end if;
    end process;
end Behavioral;