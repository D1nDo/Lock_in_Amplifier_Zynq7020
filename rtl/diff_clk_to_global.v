// Questo modulo serve a generare un clock interno alla scheda e a distribuirlo nell scheda 
// a partire da una coppia di pin differenziali

module diff_clk_to_global
(
  // Coppia differenziale in ingresso
  input  wire clk_p,
  input  wire clk_n,

  // Clock single-ended in uscita: 125 MHz dall'ADC della Red Pitaya
  // (FREQ_HZ dichiarato qui: il block design lo propaga a tutti i blocchi)
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_out CLK" *)
  (* X_INTERFACE_PARAMETER = "FREQ_HZ 125000000" *)
  output wire clk_out
);

  wire clk_int;

  // 1) Buffer differenziale 
  IBUFGDS diff_clk_buf (
    .I  (clk_p),
    .IB (clk_n),
    .O  (clk_int)
  );

  // 2) Buffer globale
  BUFG global_clk_buf (
    .I (clk_int),
    .O (clk_out)
  );

endmodule