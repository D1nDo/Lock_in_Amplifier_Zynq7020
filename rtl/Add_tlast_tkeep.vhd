library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Add_tlast_tkeep is
generic(
    AXIS_DATA_WIDTH : integer := 32;
    TLAST              : integer := 256  -- lunghezza frame
);
port(
    clk           : in  std_logic;
    
    -- AXI-Stream Slave
    s_axis_tdata  : in  signed(AXIS_DATA_WIDTH-1 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;

    -- AXI-Stream Master
    m_axis_tdata  : out signed(AXIS_DATA_WIDTH-1 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tkeep  : out std_logic_vector(7 downto 0);
    m_axis_tlast  : out std_logic
);
end entity;

architecture Behavioral of Add_tlast_tkeep is
    signal counter : integer := 0;
begin

process(clk)
begin
    if rising_edge(clk) then
        
        -- stream pass-through
        m_axis_tdata  <=  s_axis_tdata;
        m_axis_tvalid <= s_axis_tvalid;

        -- AXIS ready propagation
        s_axis_tready <= m_axis_tready;

        -- keep always 0xFFFF (tutti i byte validi)
        m_axis_tkeep <= (others => '1');
        m_axis_tlast <= '0';

        -- contatore valido solo quando il trasferimento avviene
        if s_axis_tvalid = '1' and m_axis_tready = '1' then
            
            if counter = TLAST-1 then
                m_axis_tlast <= '1';
                counter <= 0;
            else
                counter <= counter + 1;
            end if;

        end if;

    end if;
end process;

end architecture;
