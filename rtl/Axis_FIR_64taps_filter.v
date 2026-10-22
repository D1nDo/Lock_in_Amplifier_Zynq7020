module Axis_FIR_64taps_filter #(
    parameter AXIS_DATA_WIDTH = 16
)(
    input  wire                               clk,
    input  wire                               reset_n,

    input  wire signed [AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                               s_axis_tvalid,
    output wire                               s_axis_tready,

    output reg  signed [AXIS_DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                                m_axis_tvalid,
    input  wire                               m_axis_tready
);

// Parametri
localparam N_TAPS      = 64;
localparam COEFS_WIDTH = 16;
localparam PROD_WIDTH  = AXIS_DATA_WIDTH + COEFS_WIDTH;

assign s_axis_tready = m_axis_tready;

integer i;

/*--- COEFFICIENTI ---*/
wire signed [COEFS_WIDTH-1:0] COEFFS [0:N_TAPS-1];

assign COEFFS[ 0] = 16'sd271;
assign COEFFS[ 1] = 16'sd291;
assign COEFFS[ 2] = 16'sd311;
assign COEFFS[ 3] = 16'sd330;
assign COEFFS[ 4] = 16'sd350;
assign COEFFS[ 5] = 16'sd370;
assign COEFFS[ 6] = 16'sd390;
assign COEFFS[ 7] = 16'sd409;
assign COEFFS[ 8] = 16'sd428;
assign COEFFS[ 9] = 16'sd447;
assign COEFFS[10] = 16'sd465;
assign COEFFS[11] = 16'sd483;
assign COEFFS[12] = 16'sd501;
assign COEFFS[13] = 16'sd518;
assign COEFFS[14] = 16'sd534;
assign COEFFS[15] = 16'sd550;
assign COEFFS[16] = 16'sd565;
assign COEFFS[17] = 16'sd580;
assign COEFFS[18] = 16'sd594;
assign COEFFS[19] = 16'sd606;
assign COEFFS[20] = 16'sd619;
assign COEFFS[21] = 16'sd630;
assign COEFFS[22] = 16'sd640;
assign COEFFS[23] = 16'sd649;
assign COEFFS[24] = 16'sd658;
assign COEFFS[25] = 16'sd665;
assign COEFFS[26] = 16'sd672;
assign COEFFS[27] = 16'sd677;
assign COEFFS[28] = 16'sd681;
assign COEFFS[29] = 16'sd685;
assign COEFFS[30] = 16'sd687;
assign COEFFS[31] = 16'sd688;
assign COEFFS[32] = 16'sd688;
assign COEFFS[33] = 16'sd687;
assign COEFFS[34] = 16'sd685;
assign COEFFS[35] = 16'sd681;
assign COEFFS[36] = 16'sd677;
assign COEFFS[37] = 16'sd672;
assign COEFFS[38] = 16'sd665;
assign COEFFS[39] = 16'sd658;
assign COEFFS[40] = 16'sd649;
assign COEFFS[41] = 16'sd640;
assign COEFFS[42] = 16'sd630;
assign COEFFS[43] = 16'sd619;
assign COEFFS[44] = 16'sd606;
assign COEFFS[45] = 16'sd594;
assign COEFFS[46] = 16'sd580;
assign COEFFS[47] = 16'sd565;
assign COEFFS[48] = 16'sd550;
assign COEFFS[49] = 16'sd534;
assign COEFFS[50] = 16'sd518;
assign COEFFS[51] = 16'sd501;
assign COEFFS[52] = 16'sd483;
assign COEFFS[53] = 16'sd465;
assign COEFFS[54] = 16'sd447;
assign COEFFS[55] = 16'sd428;
assign COEFFS[56] = 16'sd409;
assign COEFFS[57] = 16'sd390;
assign COEFFS[58] = 16'sd370;
assign COEFFS[59] = 16'sd350;
assign COEFFS[60] = 16'sd330;
assign COEFFS[61] = 16'sd311;
assign COEFFS[62] = 16'sd291;
assign COEFFS[63] = 16'sd271;


/*--- Gestione tready ---*/
wire valid_data_in = s_axis_tvalid && m_axis_tready;

/*--- FIFO ---*/ 
reg valid_fifo;
reg signed [AXIS_DATA_WIDTH-1:0] shift_reg [0:N_TAPS-1];

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            shift_reg[i] <= 0;
        valid_fifo <= 1'b0;
    end else begin
        if (valid_data_in) begin
            for (i = N_TAPS-1; i > 0; i = i - 1)
                shift_reg[i] <= shift_reg[i-1];

            shift_reg[0] <= s_axis_tdata;
            valid_fifo   <= 1'b1;
        end else begin
            valid_fifo <= 1'b0;
        end
    end
end

/* --- Moltiplicazioni ---*/
reg signed [PROD_WIDTH-1:0] prod_reg [0:N_TAPS-1];
reg valid_mult;

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            prod_reg[i] <= 0;
        valid_mult <= 1'b0;
    end else begin
        if (valid_fifo) begin
            for (i = 0; i < N_TAPS; i = i + 1)
                prod_reg[i] <= shift_reg[i] * COEFFS[i];

            valid_mult <= 1'b1;
        end else begin
            valid_mult <= 1'b0;
        end
    end
end

/*--- Rescale dei dati ---*/
reg signed [AXIS_DATA_WIDTH-2:0] prod_reg_resized [0:N_TAPS-1];
reg valid_rescale;

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            prod_reg_resized[i] <= 0;
        valid_rescale <= 1'b0;
    end else begin
        if (valid_mult) begin
            for (i = 0; i < N_TAPS; i = i + 1)
                prod_reg_resized[i] <= prod_reg[i] >>> (COEFS_WIDTH-1);

            valid_rescale <= 1'b1;
        end else begin
            valid_rescale <= 1'b0;
        end
    end
end

/* Summation Tree ---*/
reg signed [AXIS_DATA_WIDTH-1:0] lvl0 [0:31];
reg signed [AXIS_DATA_WIDTH-1:0] lvl1 [0:15];
reg signed [AXIS_DATA_WIDTH-1:0] lvl2 [0:7];
reg signed [AXIS_DATA_WIDTH-1:0] lvl3 [0:3];
reg signed [AXIS_DATA_WIDTH-1:0] lvl4 [0:1];

reg signed [AXIS_DATA_WIDTH-1:0] sum_final;
reg valid_tree;

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < 32; i = i + 1) lvl0[i] <= 0;
        for (i = 0; i < 16; i = i + 1) lvl1[i] <= 0;
        for (i = 0; i < 8;  i = i + 1) lvl2[i] <= 0;
        for (i = 0; i < 4;  i = i + 1) lvl3[i] <= 0;
        for (i = 0; i < 2;  i = i + 1) lvl4[i] <= 0;

        sum_final  <= 0;
        valid_tree <= 1'b0;

    end else begin
        if (valid_rescale) begin

            for (i = 0; i < 32; i = i + 1)
                lvl0[i] <= prod_reg_resized[2*i] + prod_reg_resized[2*i+1];

            for (i = 0; i < 16; i = i + 1)
                lvl1[i] <= lvl0[2*i] + lvl0[2*i+1];

            for (i = 0; i < 8; i = i + 1)
                lvl2[i] <= lvl1[2*i] + lvl1[2*i+1];

            for (i = 0; i < 4; i = i + 1)
                lvl3[i] <= lvl2[2*i] + lvl2[2*i+1];

            for (i = 0; i < 2; i = i + 1)
                lvl4[i] <= lvl3[2*i] + lvl3[2*i+1];

            sum_final <= lvl4[0] + lvl4[1];

            valid_tree <= 1'b1;

        end else begin
            valid_tree <= 1'b0;
        end
    end
end

/*--- Output---*/
always @(posedge clk) begin
    if (!reset_n) begin
        m_axis_tdata  <= 0;
        m_axis_tvalid <= 1'b0;
    end else begin
        if (valid_tree) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= sum_final;
        end else begin
            m_axis_tvalid <= 1'b0;
        end
    end
end

endmodule