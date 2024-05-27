`timescale 1ns / 1ps
`default_nettype none

//module takes in a 8 bit pixel and given two threshold values it:
//produces a 1 bit output indicating if the pixel is between (inclusive)
//those two threshold values
module threshold(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] pixel_in,
  input wire [7:0] lower_bound_in, upper_bound_in,
  output logic mask_out
);
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      mask_out <= 0;
    end else begin
      mask_out <= (pixel_in > lower_bound_in) && (pixel_in <= upper_bound_in);
    end
  end
endmodule


`default_nettype wire
