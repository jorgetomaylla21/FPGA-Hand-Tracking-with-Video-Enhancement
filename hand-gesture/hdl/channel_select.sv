`timescale 1ns / 1ps
`default_nettype none

//module takes in six different channels of color (all 8 bit)
// based on switches, combinationally routes one of them to channel_out
module channel_select(
  input wire [2:0] sel_in,
  input wire [7:0] r_in, g_in, b_in,
  input wire [7:0] y_in, cr_in, cb_in,
  output logic [7:0] channel_out
);

  logic [7:0] channel;
  assign channel_out = channel;
  always_comb begin
    case (sel_in)
      3'b000: channel = g_in;
      3'b001: channel = r_in;
      3'b010: channel = b_in;
      3'b011: channel = 5'b0;
      3'b100: channel = y_in;
      3'b101: channel = cr_in;
      3'b110: channel = cb_in;
      3'b111: channel = 5'b0;
      default: channel = 5'b0;
    endcase
  end
endmodule


`default_nettype wire
