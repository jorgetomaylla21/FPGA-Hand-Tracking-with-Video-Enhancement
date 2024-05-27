`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module video_mux (
  input wire [1:0] bg_in, //regular video
  input wire [1:0] target_in, //regular video
  input wire [23:0] camera_pixel_in, //16 bits from camera 5:6:5
  input wire [7:0] camera_y_in,  //y channel of ycrcb camera conversion
  input wire [7:0] channel_in, //the channel from selection module
  input wire thresholded_pixel_in, //
  input wire [23:0] com_sprite_pixel_in,
  input wire crosshair_in,
  output logic [23:0] pixel_out
);

  /*
  00: normal camera out
  01: channel image (in grayscale)
  10: (thresholded channel image b/w)
  11: y channel with magenta mask

  upper bits:
  00: nothing:
  01: crosshair
  10: sprite on top
  11: nothing (orange test color)
  */

  logic [23:0] l_1;
  always_comb begin
    case (bg_in)
      2'b00: l_1 = camera_pixel_in;
      2'b01: l_1 = {channel_in, channel_in, channel_in};
      2'b10: l_1 = (thresholded_pixel_in !=0)?24'hFFFFFF:24'h000000;
      2'b11: l_1 = (thresholded_pixel_in != 0) ? 24'hFF77AA : {camera_y_in,camera_y_in,camera_y_in};
    endcase
  end

  logic [23:0] l_2;
  always_comb begin
    case (target_in)
      2'b00: l_2 = l_1;
      2'b01: l_2 = crosshair_in? 24'h00FF00:l_1;
      2'b10: l_2 = (com_sprite_pixel_in >0)?com_sprite_pixel_in:l_1;
      2'b11: l_2 = 24'hFF7700; //test color
    endcase
  end

  assign pixel_out = l_2;
endmodule

`default_nettype wire
