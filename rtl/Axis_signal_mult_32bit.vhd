library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Axis_signal_mult_32bit is 
generic (
    AXIS_DATA_WIDTH : integer := 16;
    MULT_REG_WIDTH  : integer := 32  -- prodotto 16+16 = 32 bit
);
port (
    clk : in std_logic;
    
    s_axis_tdata_in1  : in signed (AXIS_DATA_WIDTH-1 downto 0);
    s_axis_tvalid_in1 : in std_logic;
    s_axis_tready_in1 : out std_logic;
    
    s_axis_tdata_in2  : in signed (AXIS_DATA_WIDTH-1 downto 0);
    s_axis_tvalid_in2 : in std_logic;
    s_axis_tready_in2 : out std_logic;
    
    m_axis_tdata_out  : out signed (MULT_REG_WIDTH-1 downto 0);
    m_axis_tvalid_out : out std_logic;
    m_axis_tready_out : in std_logic
);
end entity;

architecture Behavioral of Axis_signal_mult_32bit is
    signal s_axis_tvalid_in : std_logic;
    signal mult_temp    : signed(MULT_REG_WIDTH-1 downto 0);
begin 
    -- Segnale che mi dice quando entrambi gli ingressi sono validi 
    s_axis_tvalid_in <= s_axis_tvalid_in1 and s_axis_tvalid_in2;

    -- Quando il blocco successivo (downstream) è pronto ad accettare dati allora il mio blocco è pronto ad accettarli dall upstream
    s_axis_tready_in1 <= m_axis_tready_out;
    s_axis_tready_in2 <= m_axis_tready_out;

    process (clk)
    begin 
        if rising_edge(clk) then 
            if m_axis_tready_out = '1' then  -- il blocco inizia la parte sequenziale solo se il blocco downstream è pronto ad accettare
                m_axis_tvalid_out <= s_axis_tvalid_in;  -- Il ciclo lavora in  1 clock quindi, quando i dati in ingresso sono validi anche quelli in uscita sono validi
                
                if s_axis_tvalid_in = '1' then
                    -- moltiplicazione senza saturazione perchè il registro è suffcientemente grande da evitare overflow
                    mult_temp <= s_axis_tdata_in1 * s_axis_tdata_in2;

                    -- risultato in uscita AXIS
                    m_axis_tdata_out <= mult_temp;
                end if;
            end if;
        end if;
    end process;
end architecture;