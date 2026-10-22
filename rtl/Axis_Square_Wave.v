module Axis_Square_Wave #(
    parameter integer HIGH_CYCLES = 312,
    parameter integer LOW_CYCLES  = 312,
    parameter integer SQUARE_MAGNITUDE = 4000,
    parameter integer AXIS_DATA_WIDTH  = 16
)(
    input  wire clk,
    input  wire reset_n,
    
    output reg signed [AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid
);

    reg [9:0] cnt;
    reg       square_state;

    always @(posedge clk) begin
        if (!reset_n) begin
            cnt          <= 10'd0;
            square_state <= 1'b0;
            m_axis_tdata          <= 0;
        end else begin
            // Contatore per metà periodo variabile
            if ((square_state && cnt == HIGH_CYCLES-1) || (!square_state && cnt == LOW_CYCLES-1)) begin
                cnt          <= 10'd0;
                square_state <= ~square_state; 
            end else begin
                cnt <= cnt + 1'b1;
            end

            // Output
            m_axis_tdata <= square_state ? SQUARE_MAGNITUDE : -SQUARE_MAGNITUDE;
            m_axis_tvalid <= 1'b1;
        end        
    end

endmodule