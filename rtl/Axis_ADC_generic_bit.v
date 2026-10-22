// Questo modulo impacchetta i dati provenienti dall'ADC in protocollo AXI-Stream.
// Può essere usato per qualsiasi tipo di ADC con numero di bit inferiore a 16.
// Testato per funzionare a 250 MHz

module Axis_ADC_generic_bit #
(
  parameter integer ADC_DATA_WIDTH = 14,
  parameter integer OUT_DATA_WIDTH = 16
)
(
  input  wire                     clk,
  input  wire                     reset_n,

  input  wire [ADC_DATA_WIDTH-1:0] adc_dat_a,
  input  wire [ADC_DATA_WIDTH-1:0] adc_dat_b,

  output reg  [OUT_DATA_WIDTH-1:0] m_axis_tdata_a,
  output reg  					   m_axis_tvalid_a,
  
  output reg  [OUT_DATA_WIDTH-1:0] m_axis_tdata_b,
  output reg  					   m_axis_tvalid_b
);

  localparam PADDING_WIDTH = OUT_DATA_WIDTH - ADC_DATA_WIDTH;

/* -- Cattura del dato ----*/
  reg [ADC_DATA_WIDTH-1:0] adc_a_reg;
  reg [ADC_DATA_WIDTH-1:0] adc_b_reg;

  always @(posedge clk) begin
    if (!reset_n) begin
      adc_a_reg <= 0;
      adc_b_reg <= 0;
    end else begin
      adc_a_reg <= adc_dat_a;
      adc_b_reg <= adc_dat_b;
    end
  end

/* -- Inversione bit per complemento due --*/
  reg [ADC_DATA_WIDTH-2:0] adc_a_inv;
  reg [ADC_DATA_WIDTH-2:0] adc_b_inv;
  reg                      adc_a_sign;
  reg                      adc_b_sign;
  reg                      inv_vld;

  always @(posedge clk) begin
    if (!reset_n) begin
        adc_a_inv  <= 0;
        adc_b_inv  <= 0;
        adc_a_sign <= 0;
        adc_b_sign <= 0;
        inv_vld    <= 1'b0;
    end else begin
        adc_a_inv  <= ~adc_a_reg[ADC_DATA_WIDTH-2:0];
        adc_b_inv  <= ~adc_b_reg[ADC_DATA_WIDTH-2:0];
        adc_a_sign <=  adc_a_reg[ADC_DATA_WIDTH-1];
        adc_b_sign <=  adc_b_reg[ADC_DATA_WIDTH-1];
        inv_vld <= 1'b1;
    end
  end

  /* --- Estensione del segno e uscita AXIS ---*/
  always @(posedge clk) begin
    if (!reset_n) begin
        m_axis_tdata_a <= 0;
        m_axis_tdata_b <= 0;
        m_axis_tvalid_a <= 1'b0;
        m_axis_tvalid_b <= 1'b0;
    end else begin
        if(inv_vld) begin
            m_axis_tdata_a <= { {(PADDING_WIDTH+1){adc_a_sign}}, adc_a_inv };
            m_axis_tdata_b <= { {(PADDING_WIDTH+1){adc_b_sign}}, adc_b_inv };
            m_axis_tvalid_a <= 1'b1;
            m_axis_tvalid_b <= 1'b1;
        end else begin 
            m_axis_tvalid_a <= 1'b0;
            m_axis_tvalid_b <= 1'b0;    
        end   
     end    
  end

endmodule