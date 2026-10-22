module Axis_downsampler#(
    parameter DATA_WIDTH = 16,
    parameter DECIM_FACT = 100
)(
    input  wire                         clk,
    input  wire                         reset_n,

    input  wire signed [DATA_WIDTH-1:0] s_axis_tdata,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tvalid,

    output reg  signed [DATA_WIDTH-1:0] m_axis_tdata,
    input  wire                         m_axis_tready,
    output reg                          m_axis_tvalid
);

    // AXIS handshake
    assign s_axis_tready = m_axis_tready;
    wire in_fire = s_axis_tvalid && s_axis_tready;

   // Registro contatore 
   reg [$clog2(DECIM_FACT)-1:0] cnt;
  
    /*---- Gestione contatore ---*/
    always @(posedge clk) begin
        if (!reset_n) begin
            cnt <= 0;
        end else if (in_fire) begin
            if (cnt == DECIM_FACT-1)
                cnt <= 0;
            else
                cnt <= cnt + 1;
        end
    end

    // Esco solo 1 volta ogni decimazione
    wire enable_out = (cnt == DECIM_FACT-1) && in_fire;

    /*---- Gestione output ---*/
    always @(posedge clk) begin
        if (!reset_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 0;
        end else begin
            if (enable_out) begin
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tvalid <= 1'b1;
            end else if (m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end

endmodule