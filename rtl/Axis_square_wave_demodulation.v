// Demodulazione di una square wave a 200 KHz: integra TUTTI i campioni di ciascun
// semiperiodo e in uscita fornisce (somma primo semiperiodo - somma secondo semiperiodo),
// una volta per periodo.
// - DUTY_CYCLE  : campioni per semiperiodo (deve coincidere con HIGH/LOW_CYCLES di Axis_Square_Wave)
// - PHASE_DELAY : ritardo DAC -> sistema esterno -> ADC in campioni (0 <= PHASE_DELAY < 2*DUTY_CYCLE),
//                 allinea i semiperiodi demodulati a quelli effettivamente ricevuti
// - BLANK       : campioni scartati dopo ogni fronte per escludere i transitori (0 <= BLANK < DUTY_CYCLE)
// Uscita a OUT_DATA_WIDTH bit: con i default (16 bit, 312 campioni) la differenza occupa
// 26 bit, quindi non serve saturazione. Se OUT_DATA_WIDTH è troppo piccolo l'uscita satura.

module Axis_square_wave_demodulation #(
    parameter integer AXIS_DATA_WIDTH = 16,
    parameter integer OUT_DATA_WIDTH  = 32,
    parameter integer DUTY_CYCLE      = 312,
    parameter integer PHASE_DELAY     = 0,
    parameter integer BLANK           = 0
)(
    input  wire                              clk,
    input  wire                              reset_n,

    input  wire signed [AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                              s_axis_tvalid,
    output wire                              s_axis_tready,

    output reg  signed [OUT_DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                               m_axis_tvalid,
    input  wire                              m_axis_tready
);

    // Dimensioni
    localparam integer PERIOD = 2*DUTY_CYCLE;
    localparam integer CNT_W  = $clog2(PERIOD);
    localparam integer ACC_W  = AXIS_DATA_WIDTH + $clog2(DUTY_CYCLE+1); // somma di DUTY_CYCLE campioni
    localparam integer DIFF_W = ACC_W + 1;

    // Handshake AXIS in ingresso
    wire fire = s_axis_tvalid & m_axis_tready;
    assign s_axis_tready = m_axis_tready;

    // Registri di controllo
    reg [CNT_W-1:0] cnt;
    reg             primed;   // il primo periodo dopo il reset è parziale: lo scarto
    reg             diff_vld;

    // Registri di accumulo
    reg signed [ACC_W-1:0]  acc_1, acc_2;
    reg signed [DIFF_W-1:0] diff;

    // Posizione nel periodo
    wire             first_half = (cnt < DUTY_CYCLE);
    wire [CNT_W-1:0] idx        = first_half ? cnt : cnt - DUTY_CYCLE;
    wire             take       = (idx >= BLANK);
    wire             end_period = (cnt == PERIOD-1);

	/* INTEGRO I DUE SEMIPERIODI E SOTTRAGGO */
    always @(posedge clk) begin
        if (!reset_n) begin
            cnt      <= (PERIOD - PHASE_DELAY) % PERIOD;
            primed   <= 1'b0;
            acc_1    <= 0;
            acc_2    <= 0;
            diff     <= 0;
            diff_vld <= 1'b0;
        end else begin
            diff_vld <= 1'b0;

            if (fire) begin
                if (end_period) begin
                    // L'ultimo campione appartiene al secondo semiperiodo (idx = DUTY_CYCLE-1 >= BLANK)
                    diff     <= acc_1 - (acc_2 + s_axis_tdata);
                    diff_vld <= primed;
                    primed   <= 1'b1;
                    acc_1    <= 0;
                    acc_2    <= 0;
                    cnt      <= 0;
                end else begin
                    cnt <= cnt + 1'b1;
                    if (take) begin
                        if (first_half)
                            acc_1 <= acc_1 + s_axis_tdata;
                        else
                            acc_2 <= acc_2 + s_axis_tdata;
                    end
                end
            end
        end
    end

	/* SATURAZIONE (solo se DIFF_W > OUT_DATA_WIDTH) */
    wire signed [OUT_DATA_WIDTH-1:0] diff_out;

    generate
        if (DIFF_W > OUT_DATA_WIDTH) begin : g_sat
            wire signed [DIFF_W-1:0] max_s = {{(DIFF_W-OUT_DATA_WIDTH+1){1'b0}}, {(OUT_DATA_WIDTH-1){1'b1}}};
            wire signed [DIFF_W-1:0] min_s = {{(DIFF_W-OUT_DATA_WIDTH+1){1'b1}}, {(OUT_DATA_WIDTH-1){1'b0}}};
            assign diff_out = (diff > max_s) ? max_s[OUT_DATA_WIDTH-1:0] :
                              (diff < min_s) ? min_s[OUT_DATA_WIDTH-1:0] :
                                               diff[OUT_DATA_WIDTH-1:0];
        end else begin : g_ext
            assign diff_out = diff; // estensione del segno
        end
    endgenerate

	/* USCITA AXIS */
    always @(posedge clk) begin
        if (!reset_n) begin
            m_axis_tdata  <= 0;
            m_axis_tvalid <= 1'b0;
        end else begin
            if (diff_vld)
                m_axis_tdata <= diff_out;
            m_axis_tvalid <= diff_vld;
        end
    end

endmodule
