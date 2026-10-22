library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Axis_signal_splitter_or is 
    generic(
        DATA_WIDTH : integer := 16
    );
    port(
        clk : in std_logic;

        s_axis_tdata_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid_in : in  std_logic;
        s_axis_tready_in : out std_logic;

        m_axis_tdata_out1  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid_out1 : out std_logic;
        m_axis_tready_out1 : in  std_logic;

        m_axis_tdata_out2  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid_out2 : out std_logic;
        m_axis_tready_out2 : in  std_logic
    );
end Axis_signal_splitter_or;

architecture Behavioral of Axis_signal_splitter_or is
    signal signal_in       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal out_ready_enable: std_logic;
begin

    -- Segnale combinatorio per abilitare l'uscita
    out_ready_enable <= m_axis_tready_out1 or m_axis_tready_out2;

    process(clk)
    begin
        if rising_edge(clk) then
            if s_axis_tvalid_in = '1' then
                -- segnalo che siamo pronti a ricevere dati
                s_axis_tready_in <= '1';
                -- registro i dati in ingresso
                signal_in <= s_axis_tdata_in;

                if out_ready_enable = '1' then
                    -- mando i dati in uscita
                    m_axis_tdata_out1  <= signal_in;
                    m_axis_tdata_out2  <= signal_in;
                    m_axis_tvalid_out1 <= '1';
                    m_axis_tvalid_out2 <= '1';
                end if;
            end if;
        end if;
    end process;

end Behavioral;