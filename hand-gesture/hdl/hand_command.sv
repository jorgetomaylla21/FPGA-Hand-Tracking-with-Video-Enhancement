`timescale 1ns / 1ps
`default_nettype none

module hand_command(
  input wire clk_in,
  input wire rst_in,
  input wire valid_in,
  input wire data_in [5:1],
  output logic [3:0] data_out,
  output logic valid_signal_out
);
// when signals are ready, output valid_signal_out for only 1 cycle, send 0 if no blobs detected

always_ff @(posedge clk_in) begin
    if (rst_in) begin
        valid_signal_out <= 0;
    end else begin
        if (valid_in) begin
            //count the valid blobs (in display)
            data_out <= data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5]; 
            valid_signal_out <= 1'b1;
        end else begin
            valid_signal_out <= 1'b0;
        end
        
    end
    end

endmodule


`default_nettype wire