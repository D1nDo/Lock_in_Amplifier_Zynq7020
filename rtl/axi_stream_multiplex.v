module axi_stream_multiplex (
    // Clock e reset (reset aggiunto per best practice, anche se non strettamente usato qui)
    input wire clk,
    
    // Segnale di selezione (0 = Canale 1, 1 = Canale 2)
    input wire sel,
    
    // Interface AXI-Stream per Segnale 1 (S1)
    input wire [31:0] s1_axis_tdata,  // Portato a 32 bit
    input wire s1_axis_tvalid,
    output wire s1_axis_tready,
    input wire s1_axis_tlast,
    
    // Interface AXI-Stream per Segnale 2 (S2)
    input wire [31:0] s2_axis_tdata,  // Portato a 32 bit
    input wire s2_axis_tvalid,
    output wire s2_axis_tready,
    input wire s2_axis_tlast,
    
    // Interface AXI-Stream in uscita (Master)
    output wire [31:0] m_axis_tdata,  // Portato a 32 bit
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// Registro per campionare il segnale di selezione per evitare glitch sincroni
reg selected_channel;

always @(posedge clk) begin
    selected_channel <= sel;
end

// Logica del multiplexer (Combinatoria)
// Se selected_channel è 1, passa S2, altrimenti passa S1
assign m_axis_tdata  = (selected_channel) ? s2_axis_tdata  : s1_axis_tdata;
assign m_axis_tvalid = (selected_channel) ? s2_axis_tvalid : s1_axis_tvalid;
assign m_axis_tlast  = (selected_channel) ? s2_axis_tlast  : s1_axis_tlast;

// Gestione dei segnali TREADY (Backpressure)
// Il ready viene propagato solo al canale attualmente selezionato
assign s1_axis_tready = (!selected_channel) ? m_axis_tready : 1'b0;
assign s2_axis_tready = (selected_channel)  ? m_axis_tready : 1'b0;

endmodule