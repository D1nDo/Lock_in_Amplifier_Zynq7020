// Square wave -> ritardo D campioni, guadagno G, offset OFS -> demodulatore -> CIC
module tb_square;
    localparam integer HALF = 312, D = 37, BLANK = 5, M = 4000;
    localparam integer G_NUM = 3, G_DEN = 4, OFS = 1234;
    localparam integer R = 16, RW = 32 + 3*4, OW = 32;

    reg clk = 0, reset_n = 0;
    always #4 clk = ~clk;

    wire signed [15:0] sq;  wire sq_vld;
    Axis_Square_Wave #(.HIGH_CYCLES(HALF), .LOW_CYCLES(HALF), .SQUARE_MAGNITUDE(M))
        gen (.clk(clk), .reset_n(reset_n), .m_axis_tdata(sq), .m_axis_tvalid(sq_vld));

    // canale: ritardo di D campioni + guadagno + offset (ADC sempre valido)
    reg signed [15:0] dl [0:D-1];
    integer i;
    always @(posedge clk) begin
        dl[0] <= sq * G_NUM / G_DEN + OFS;
        for (i = 1; i < D; i = i + 1) dl[i] <= dl[i-1];
    end
    wire signed [15:0] adc = dl[D-2]; // gen ha 1 ciclo di registro: ritardo totale = D

    wire signed [31:0] dem; wire dem_vld;
    Axis_square_wave_demodulation #(.DUTY_CYCLE(HALF), .PHASE_DELAY(D), .BLANK(BLANK))
        dut (.clk(clk), .reset_n(reset_n), .s_axis_tdata(adc), .s_axis_tvalid(1'b1),
             .s_axis_tready(), .m_axis_tdata(dem), .m_axis_tvalid(dem_vld), .m_axis_tready(1'b1));

    wire signed [OW-1:0] cic; wire cic_vld;
    Axis_CIC_filter_3_stages #(.DATA_WIDTH_IN(32), .DATA_WIDTH_OUT(OW), .DEC_RATIO(R), .REG_WIDTH(RW))
        cicf (.clk(clk), .reset_n(reset_n), .s_axis_tdata(dem), .s_axis_tvalid(dem_vld),
              .s_axis_tready(), .m_axis_tdata(cic), .m_axis_tready(1'b1), .m_axis_tvalid(cic_vld));

    // atteso: -(HALF-BLANK) * 2 * M*G
    localparam integer EXP = -(HALF-BLANK) * 2 * (M*G_NUM/G_DEN);
    // CIC: guadagno R^3 = 2^12, poi prende i bit alti (RW-OW = 12) -> uscita = ingresso
    integer n_dem = 0, n_cic = 0, err = 0;
    always @(posedge clk) begin
        if (dem_vld) begin
            n_dem = n_dem + 1;
            if (dem !== EXP) begin err = err + 1; $display("DEM ERR #%0d: %0d (atteso %0d)", n_dem, dem, EXP); end
        end
        if (cic_vld) begin
            n_cic = n_cic + 1;
            if (n_cic > 3 && cic !== EXP) begin err = err + 1; $display("CIC ERR #%0d: %0d (atteso %0d)", n_cic, cic, EXP); end
        end
    end

    initial begin
        repeat (10) @(posedge clk);
        reset_n = 1;
        repeat (2*HALF*R*8) @(posedge clk);
        $display("demod out: %0d campioni, CIC out: %0d campioni, atteso %0d, errori: %0d", n_dem, n_cic, EXP, err);
        $display(err == 0 ? "PASS" : "FAIL");
        $finish;
    end
endmodule
