// Filtro CIC con
// - 3 stages di integrazione
// - 3 stages di comb
// - differential delay pari a 1,
// ATTENZIONE a cambiare i parameteri, segui la regola:
// REG_WIDTH = DATA_WIDTH_IN + N*log_2(R*M)
// dove: N = numero di stadi, R = Decimation ratio, M = Differential delay
// NB: la decimazione conta i CAMPIONI VALIDI in ingresso (non i cicli di clock),
// quindi il filtro funziona anche con stream non continui (es. tvalid a impulsi).

module Axis_CIC_filter_3_stages #(
    parameter DATA_WIDTH_IN  = 32,
    parameter DATA_WIDTH_OUT = 32,  // multiplo di 8 (vincolo AXIS TDATA)
	parameter DEC_RATIO      = 32,  // Fattore di decimazione
	parameter REG_WIDTH      = 48  // 32 + 3*log_2(32*1) = 47 bit (per eccesso a 48 bit)
)(
    input  wire                         clk,
    input  wire                         reset_n,

    input  wire signed [DATA_WIDTH_IN-1:0]  s_axis_tdata,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tvalid,

    output reg  signed [DATA_WIDTH_OUT-1:0] m_axis_tdata,
    input  wire                             m_axis_tready,
    output reg                              m_axis_tvalid
);

    // Protocollo axis handshake
    assign s_axis_tready = m_axis_tready;
    wire in_ready = s_axis_tvalid && m_axis_tready;

    // Registri degli integratori
    reg signed [REG_WIDTH-1:0] d1, d2, d3;
    reg vld1, vld2, vld3;

    //Registri per decimatore
    reg [15:0] count;
    reg signed [REG_WIDTH-1:0] d_tmp;
    reg v_comb;

    // Registri per Comb
    reg signed [REG_WIDTH-1:0] d4, d5, d6;
    reg signed [REG_WIDTH-1:0] d_d4, d_d5, d_d6;
    reg vld4, vld5, vld6;

	/* --- INTEGRATORE (3-stages) e DECIMATORE --- */
    always @(posedge clk) begin
        if (!reset_n) begin
            d1 <= 0; d2 <= 0; d3 <= 0;
            vld1 <= 0; vld2 <= 0; vld3 <= 0;
            count <= 0;
            d_tmp <= 0;
            v_comb <= 0;
        end else begin

            /* ---- Integratori ---- */
            if (in_ready) begin
                d1   <= d1 + s_axis_tdata; // Integratore 1
                vld1 <= 1'b1;
            end else
                vld1 <= 1'b0;

            if (vld1) begin
                d2   <= d2 + d1;  // Integratore 2
                vld2 <= 1'b1;
            end else
                vld2 <= 1'b0;

            if (vld2) begin
                d3   <= d3 + d2;  // Integratore 3
                vld3 <= 1'b1;
            end else
                vld3 <= 1'b0;

            /* ---- Decimazione (1 uscita ogni DEC_RATIO campioni validi) ---- */
            if (vld3) begin
                if (count == DEC_RATIO - 1) begin
                    count  <= 0;
                    d_tmp  <= d3;
                    v_comb <= 1'b1;
                end else begin
                    count  <= count + 1'b1;
                    v_comb <= 1'b0;
                end
            end else
                v_comb <= 1'b0;
        end
    end

	/*--- COMB (3-stages) ---*/
    always @(posedge clk) begin
        if (!reset_n) begin
            d4 <= 0; d5 <= 0; d6 <= 0;
            d_d4 <= 0; d_d5 <= 0; d_d6 <= 0;
            vld4 <= 0; vld5 <= 0; vld6 <= 0;
			m_axis_tdata  <= 0;
            m_axis_tvalid <= 1'b0;
        end else begin

            /* ---- Comb 1 ---- */
            if (v_comb) begin
                d4   <= d_tmp - d_d4;
                d_d4 <= d_tmp;
                vld4 <= 1'b1;
            end else
                vld4 <= 1'b0;

            /* ---- Comb 2 ---- */
            if (vld4) begin
                d5   <= d4 - d_d5;
                d_d5 <= d4;
                vld5 <= 1'b1;
            end else
                vld5 <= 1'b0;

            /* ---- Comb 3 ---- */
            if (vld5) begin
                d6   <= d5 - d_d6;
				d_d6 <= d5;
                vld6 <= 1'b1;
            end else
                vld6 <= 1'b0;

            /* ---- Output ---- */
            if (vld6) begin
                m_axis_tdata  <= d6[REG_WIDTH-1:REG_WIDTH - DATA_WIDTH_OUT];
                m_axis_tvalid <= 1'b1;
            end else
                m_axis_tvalid <= 1'b0;
        end
    end

endmodule
