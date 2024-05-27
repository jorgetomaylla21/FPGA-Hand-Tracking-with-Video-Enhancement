`timescale 1ns / 1ps
`default_nettype none

module rotate (
  input wire clk_in,
  input wire rst_in,
  input wire[10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire valid_addr_in,
  output logic [16:0] pixel_addr_out,
  output logic valid_addr_out);

  logic [10:0] rot_hcount;
  logic [9:0] rot_vcount;

  always_comb begin
    rot_hcount = 319-vcount_in;
    rot_vcount = hcount_in;
  end
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      valid_addr_out <= 0;
      pixel_addr_out <= 0;
    end else begin
      valid_addr_out <= valid_addr_in;
      if (valid_addr_in)begin
        pixel_addr_out <= 320*rot_vcount + rot_hcount;
      end
    end
  end
endmodule


//module rotate (
//  input wire cam_clk_in,
//  input wire valid_pixel_in,
//  input wire [15:0] pixel_in,
//  input wire frame_done_in,
//
//  output logic [15:0] pixel_out,
//  output logic [16:0] pixel_addr_out,
//  output logic valid_pixel_out
//  );
//
//  logic [8:0] pixel_count;
//
//  always_ff @(posedge cam_clk_in)begin
//    valid_pixel_out <= valid_pixel_in;
//    pixel_out <= pixel_in;
//    if (frame_done_in)begin
//      pixel_addr_out <= 240*319;
//      pixel_count <= 319;
//    end else if (valid_pixel_in)begin
//      if (pixel_count==0)begin
//        pixel_addr_out <= pixel_addr_out + 1 + 240*319; //up by one
//        pixel_count <= 319;
//      end else begin
//        pixel_addr_out <= pixel_addr_out - 240;
//        pixel_count <= pixel_count - 1;
//      end
//    end
//  end
//endmodule

`default_nettype wire
