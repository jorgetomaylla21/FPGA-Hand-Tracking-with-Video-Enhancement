`timescale 1ns / 1ps
`default_nettype none

module camera(
  input wire cam_clk_in,
  input wire vsync_in,
  input wire href_in,
  input wire [7:0] pixel_in,

  input wire clk_pixel_in,
  output logic pmodbclk,
  output logic pmodblock,
  output logic [15:0] pixel_out,
  output logic pixel_valid_out,
  output logic frame_done_out
  );

  /* Camera Reset */
  parameter STARTUP_DELAY = 74_250_000;
  logic [$clog2(STARTUP_DELAY)-1:0] startup_counter;
  always_ff @(posedge clk_pixel_in) begin
      if (startup_counter == STARTUP_DELAY) pmodblock <= 1;
      else begin
          pmodblock <= 0;
          startup_counter <= startup_counter + 1;
      end
  end

  /* XCLK Generation */
  logic xclk;
  logic[2:0] xclk_count;
  always_ff @(posedge clk_pixel_in) begin
    xclk_count <= xclk_count + 1;
  end
  assign pmodbclk = (xclk_count > 4);

  /* Pixel Read State Machine */
  //localparam WAIT_FRAME_START = 0;
  //localparam ROW_CAPTURE = 1;
  typedef enum {WAIT_FRAME_START, ROW_CAPTURE} fsm_state;
  fsm_state state = WAIT_FRAME_START;
  //logic [1:0] fsm_state = 0;
  logic pixel_half = 0;
  logic old_cam_clk_in;
	always_ff @(posedge clk_pixel_in) begin
    old_cam_clk_in <= cam_clk_in;
    if (cam_clk_in && ~ old_cam_clk_in)begin
      case(state)
        WAIT_FRAME_START: begin //wait for VSYNC
          state <= (~vsync_in) ? ROW_CAPTURE : WAIT_FRAME_START;
          frame_done_out <= 0;
          pixel_valid_out <= 0; //bad spot reading junk at the vsynch spot
          pixel_half <= 0;
        end

        ROW_CAPTURE: begin
          state <= vsync_in ? WAIT_FRAME_START : ROW_CAPTURE;
          frame_done_out <= vsync_in ? 1 : 0;
          pixel_valid_out <= (href_in && pixel_half) ? 1 : 0;
          if (href_in) begin
            pixel_half <= ~ pixel_half;
            if (pixel_half) pixel_out[7:0] <= pixel_in;
            else pixel_out[15:8] <= pixel_in;
          end
        end
      endcase
    end
  end
endmodule

`default_nettype wire
