module recover (
  input wire valid_pixel_in,
  input wire [15:0] pixel_in,
  input wire frame_done_in,

  input wire system_clk_in,
  input wire rst_in,
  output logic [15:0] pixel_out,

  output logic data_valid_out,
  output logic [10:0] hcount_out,
  output logic [9:0] vcount_out);

  logic old_valid_pixel_in;
  logic [10:0] hcount;
  logic [9:0] vcount;

  assign hcount_out = hcount;
  assign vcount_out = vcount;

  always_ff @(posedge system_clk_in) begin
    old_valid_pixel_in <= valid_pixel_in;
    if (rst_in)begin
      hcount <= 0;
      vcount <= 0;
      old_valid_pixel_in <= 0;
      data_valid_out <= 0;
    end else if (frame_done_in)begin
      hcount <= 0;
      vcount <= 0;
      data_valid_out <= 0;
    end else begin
      if (valid_pixel_in && ~old_valid_pixel_in)begin
        data_valid_out <= 1;
        pixel_out <= pixel_in;
        if (hcount==319)begin
          hcount <= 0;
          vcount <= vcount +1;
        end else begin
          hcount <= hcount + 1;
        end
      end else begin
        data_valid_out <= 0;
      end
    end
  end
endmodule
