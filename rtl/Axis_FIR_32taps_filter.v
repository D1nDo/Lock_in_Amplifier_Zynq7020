// Filtro FIR 

module Axis_FIR_32taps_filter #(
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


// Dimensioni e parametri 
localparam N_TAPS = 32;
localparam COEFS_WIDTH = 16;
localparam PROD_WIDTH = AXIS_DATA_WIDTH + COEFS_WIDTH;
    
// Gestione Axis 
assign s_axis_tready = m_axis_tready;

// parametro per i for loop
integer i;

reg signed [AXIS_DATA_WIDTH-1:0] lvl0 [0:N_TAPS/2-1];
reg signed [AXIS_DATA_WIDTH-1:0] lvl1 [0:N_TAPS/4-1];
reg signed [AXIS_DATA_WIDTH-1:0] lvl2 [0:N_TAPS/8-1];
reg signed [AXIS_DATA_WIDTH-1:0] lvl3 [0:N_TAPS/16-1];

reg signed [AXIS_DATA_WIDTH-1:0] sum_final;

// Coefficienti

wire signed [COEFS_WIDTH-1:0] COEFFS [0:N_TAPS-1];

assign COEFFS[ 0] = 16'sd385;
assign COEFFS[ 1] = 16'sd471;
assign COEFFS[ 2] = 16'sd562;
assign COEFFS[ 3] = 16'sd655;
assign COEFFS[ 4] = 16'sd750;
assign COEFFS[ 5] = 16'sd845;
assign COEFFS[ 6] = 16'sd938;
assign COEFFS[ 7] = 16'sd1027;
assign COEFFS[ 8] = 16'sd1112;
assign COEFFS[ 9] = 16'sd1190;
assign COEFFS[10] = 16'sd1259;
assign COEFFS[11] = 16'sd1320;
assign COEFFS[12] = 16'sd1369;
assign COEFFS[13] = 16'sd1408;
assign COEFFS[14] = 16'sd1434;
assign COEFFS[15] = 16'sd1447;
assign COEFFS[16] = 16'sd1447;
assign COEFFS[17] = 16'sd1434;
assign COEFFS[18] = 16'sd1408;
assign COEFFS[19] = 16'sd1369;
assign COEFFS[20] = 16'sd1320;
assign COEFFS[21] = 16'sd1259;
assign COEFFS[22] = 16'sd1190;
assign COEFFS[23] = 16'sd1112;
assign COEFFS[24] = 16'sd1027;
assign COEFFS[25] = 16'sd938;
assign COEFFS[26] = 16'sd845;
assign COEFFS[27] = 16'sd750;
assign COEFFS[28] = 16'sd655;
assign COEFFS[29] = 16'sd562;
assign COEFFS[30] = 16'sd471;
assign COEFFS[31] = 16'sd385;


/*--- FIFO ---*/

wire valid_data_in;
assign valid_data_in = s_axis_tvalid && m_axis_tready;

reg valid_fifo;
reg signed [AXIS_DATA_WIDTH-1:0] shift_reg [0:N_TAPS-1];

always @(posedge clk) begin  // reset asincroni
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            shift_reg[i] <= 0;
        valid_fifo <= 1'b0;
    end
    else begin
        if (valid_data_in) begin
		
			// Shifto i dati nella FIFO
            for (i = N_TAPS-1; i > 0; i = i - 1) 
                shift_reg[i] <= shift_reg[i-1];
			
			// Carico l'ultimo dato
            shift_reg[0] <= s_axis_tdata;
			
			valid_fifo <= 1'b1;
        end else begin
			valid_fifo <= 1'b0;
		end
    end
end

/*--- Moltiplicazioni ---*/

reg signed [PROD_WIDTH-1:0]      		prod_reg  [0:N_TAPS-1];
reg signed [AXIS_DATA_WIDTH-1-1:0]      prod_reg_resized  [0:N_TAPS-1];
reg valid_mult, valid_rescale;

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            prod_reg[i] <= 0;
        valid_mult <= 1'b0;
    end else begin
        
        // Moltiplico
        if (valid_fifo) begin
            for (i = 0; i < N_TAPS; i = i + 1)
                prod_reg[i] <= (shift_reg[i] * COEFFS[i]);
                
            valid_mult <= 1'b1;
		end else 
		    valid_mult <= 1'b0;
    end
end
              
 /*--- Rescale del segnale ---*/               
always @(posedge clk) begin	
    if (!reset_n) begin
        for (i = 0; i < N_TAPS; i = i + 1)
            prod_reg_resized[i] <= 0;
        valid_rescale <= 1'b0;
    end else begin	
    
    // Faccio recale del segnale	
    if(valid_mult) begin 
        for  (i = 0; i < N_TAPS; i = i + 1)
            prod_reg_resized[i] <= prod_reg[i] >>> (COEFS_WIDTH-1);           
            valid_rescale <= 1'b1;
        end else
			valid_rescale <= 1'b0;		
    end
end


/*--- Summation Tree ---*/

reg valid_tree;

always @(posedge clk) begin
    if (!reset_n) begin
        for (i = 0; i < N_TAPS/2; i = i + 1)
            lvl0[i] <= 0;
        for (i = 0; i < N_TAPS/4; i = i + 1)
            lvl1[i] <= 0;
        for (i = 0; i < N_TAPS/8; i = i + 1)
            lvl2[i] <= 0;
        for (i = 0; i < N_TAPS/16; i = i + 1)
            lvl3[i] <= 0;

        sum_final <= 0;
        valid_tree <= 1'b0;
    end
    else begin
		
		// faccio le somme
        if (valid_rescale) begin

            for (i = 0; i < N_TAPS/2; i = i + 1)
                lvl0[i] <= prod_reg_resized[2*i] + prod_reg_resized[2*i+1];

            for (i = 0; i < N_TAPS/4; i = i + 1)
                lvl1[i] <= lvl0[2*i] + lvl0[2*i+1];

            for (i = 0; i < N_TAPS/8; i = i + 1)
                lvl2[i] <= lvl1[2*i] + lvl1[2*i+1];

            for (i = 0; i < N_TAPS/16; i = i + 1)
                lvl3[i] <= lvl2[2*i] + lvl2[2*i+1];

            sum_final <= lvl3[0] + lvl3[1];
			
			valid_tree <= 1'b1;
        end else begin 
			valid_tree <= 1'b0;
		end
    end
end


/*--- Uscita AXIS ---*/

always @(posedge clk) begin
    if (!reset_n) begin
        m_axis_tdata  <= 0;
        m_axis_tvalid <= 1'b0;
    end
    else begin
		if(valid_tree) begin 	
			m_axis_tvalid <= 1'b1;
			m_axis_tdata <= sum_final[AXIS_DATA_WIDTH-1:0];
		end else begin 
			m_axis_tvalid <= 1'b0;
		end
    end
end

endmodule