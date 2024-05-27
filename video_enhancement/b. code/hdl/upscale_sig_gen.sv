`timescale 1ns / 1ps
`default_nettype none

module upscale_sig_gen #(
  parameter TOTAL_PIXELS = 1650,
  parameter TOTAL_LINES  = 750,
  parameter UPSAMPLE_WIDTH = 512,
  parameter UPSAMPLE_HEIGHT= 512
)(
    input wire clk_in,
    input wire [10:0] h_offset,
    input wire [9:0]  v_offset,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    // For filtering original frame
    output logic [10:0] hcount_filter_out,
    output logic [9:0] vcount_filter_out,
    output logic valid_filter_out,
    output logic frame_rst_out,

    // For reading frame with the filter applied
    output logic [10:0] hcount_upscale_out,
    output logic [9:0] vcount_upscale_out,
    output logic valid_upscale_out
);
    localparam FILTER_WIDTH = UPSAMPLE_WIDTH >> 2;
    localparam FILTER_HEIGHT = UPSAMPLE_HEIGHT >> 2;
    localparam START_UPSAMPLING = 1024;

    // for timing requirement, calculate vcount of the next row in advance
    logic [10:0] vcount_next_row;
    // counter for 3 x 3 raster pattern read
    logic [9:0] vcount_filter;
    logic [1:0] v_raster_count;

    // Function 1: Read frame buffer with 3 x 3 raster pattern
    always_ff @(posedge clk_in) begin
        if (hcount_in == 0) begin
            // configuration for starting a new line
            v_raster_count <= 2'b0;
            hcount_filter_out <= h_offset;
            
            // set vcount reference point to start reading
            if (vcount_in == TOTAL_LINES - 4) begin
                vcount_filter <= v_offset;
                // new frame signal
                frame_rst_out <= 1'b1;

            end else if ((vcount_in >= TOTAL_LINES - 4) || 
                        (vcount_in < UPSAMPLE_HEIGHT - 4 && vcount_in[1:0]==2'b11)) begin
                vcount_filter <= vcount_filter + 1;
            end

        end else if (hcount_in < (FILTER_WIDTH+3+2)*3 + 1) begin
            frame_rst_out <= 1'b0;

            // efficient counter 0->1->2->0... (initiated with 3->0->1->2...)
            v_raster_count <= {!v_raster_count[1] && v_raster_count[0], !v_raster_count[1] && !v_raster_count[0]};
            
            // update address to read from the frame buffer
            vcount_filter_out <= vcount_filter + v_raster_count;

            if (v_raster_count == 2) begin
                hcount_filter_out <= hcount_filter_out + 1;
            end

            // enable when valid row
            if (vcount_in >= TOTAL_LINES - 4
             || (vcount_in < UPSAMPLE_HEIGHT - 4 && vcount_in[1:0]==2'b11)) begin
                valid_filter_out <= 1'b1;
            end

        end else begin
            valid_filter_out <= 1'b0;
        end
    end


    always_ff @(posedge clk_in) begin
        // hcount is used from 1024 ~ 1024 + (128 + 3) << 2 (to scan 131 x 131 original pixels)
        hcount_upscale_out <= (hcount_in >> 2) - (START_UPSAMPLING>>2); //{2'b0, hcount_in[9:2]};
        vcount_next_row    <= (vcount_in >> 2) + 1'b1;

        // Start calculating the next line (after previous line is finished displaying)
        if (hcount_in >= START_UPSAMPLING && hcount_in < START_UPSAMPLING + UPSAMPLE_WIDTH + 3 * 4) begin

            // Case 1: Final line of the frame
            if (vcount_in == TOTAL_LINES - 1) begin
                // periodically scan each pixel column of length 4
                vcount_upscale_out <= hcount_in[1:0];
                valid_upscale_out <= 1'b1;

            // Case 2: Right before reading the new line
            end else if (vcount_in < UPSAMPLE_HEIGHT - 4 && vcount_in[1:0] == 2'b11) begin
                vcount_upscale_out <= vcount_next_row + hcount_in[1:0];
                valid_upscale_out <= 1'b1;

            // Otherwise, invalid region
            end else begin
                valid_upscale_out <= 1'b0;
            end

        // Invalid hcount range to read new pixel from the buffer
        end else begin
            valid_upscale_out <= 1'b0;
        end
    end
endmodule


`default_nettype wire

