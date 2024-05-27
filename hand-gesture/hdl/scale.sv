`timescale 1ns / 1ps
`default_nettype none

module scale(
  input wire [1:0] scale_in,
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  output logic [10:0] scaled_hcount_out,
  output logic [9:0] scaled_vcount_out,
  output logic valid_addr_out
);
  //always just default to scale 1
  always_comb begin
    case(scale_in)
      2'b10: begin
        //mixed scaling, 4X horizontal, 2X vertical
        valid_addr_out = hcount_in <240 * 4 && vcount_in <320 * 2;
        scaled_hcount_out = hcount_in >> 2;
        scaled_vcount_out = vcount_in >> 1;
      end
      2'b11: begin
        //2X horizontal and vertical
        valid_addr_out = hcount_in <240 * 2 && vcount_in <320 * 2;
        scaled_hcount_out = hcount_in >> 1;
        scaled_vcount_out = vcount_in >> 1;
      end
      default:begin
        //1X normal camera
        valid_addr_out = hcount_in <240 && vcount_in <320;
        scaled_hcount_out = hcount_in;
        scaled_vcount_out = vcount_in;
      end
    endcase
  end
  //(you need to update/modify this to spec)!
  // assign valid_addr_out = hcount_in <240 && vcount_in <320;
  // assign scaled_hcount_out = hcount_in;
  // assign scaled_vcount_out = vcount_in;


endmodule


`default_nettype wire

