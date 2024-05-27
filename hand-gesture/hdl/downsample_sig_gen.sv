`default_nettype none
`timescale 1ns / 1ps

module downsample_sig_gen #(
    parameter TOTAL_PIXELS = 1650,
    parameter TOTAL_LINES  = 750,
    parameter CAM_WIDTH = 240,
    parameter CAM_HEIGHT = 320,
    parameter FILTER_SIZE = 5
)(
    input wire clk_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    output logic [10:0] hcount_ds_out,
    output logic [9:0] vcount_ds_out,
    output logic valid_ds_out,
    output logic valid_draw_out
);
    localparam REQUIRED_LINES = $rtoi($ceil(CAM_HEIGHT*CAM_WIDTH/TOTAL_PIXELS));

    logic [10:0] hcount_ds;
    logic [9:0] vcount_ds;
    logic valid_ds;
    logic [$clog2(FILTER_SIZE)-1:0] vertical_counter;

    assign valid_draw_out = hcount_in < CAM_WIDTH && vcount_in < CAM_HEIGHT;

    // scan through 320 * 240 pixels with 5 x 5 raster pattern
    always_ff @(posedge clk_in) begin
        hcount_ds_out <= hcount_ds;
        vcount_ds_out <= vcount_ds + vertical_counter;
        valid_ds_out  <= valid_ds;

        if (valid_draw_out) begin
            hcount_ds_out <= hcount_in;
            vcount_ds_out <= vcount_in;

        // Case 1: Triggering the scan
        end else if ((vcount_in ==TOTAL_LINES - REQUIRED_LINES - 2) && hcount_in == 0) begin
            hcount_ds <= 0;
            vcount_ds <= 0;
            vertical_counter <= 0;
            valid_ds <= 1'b1;

        end else if (valid_ds) begin
            // Case 2: Finished Scanning through
            if (hcount_ds >= CAM_WIDTH-1 && 
                (vcount_ds >= CAM_HEIGHT - FILTER_SIZE && vertical_counter == FILTER_SIZE-1)) begin
                valid_ds <= 1'b0;

            end else begin
                // vertical counter increments by 1 within the cyclic range [0, FILTER_SIZE)
                vertical_counter <= (vertical_counter >= FILTER_SIZE-1)? 0 : vertical_counter + 1'b1;

                if (vertical_counter == FILTER_SIZE - 1)begin
                    if (hcount_ds >= CAM_WIDTH - 1) begin
                        hcount_ds <= 0;
                        vcount_ds <= vcount_ds + FILTER_SIZE;
                    end else begin
                        hcount_ds <= hcount_ds + 1'b1;
                    end
                end
            end

        end 
    end

endmodule


`default_nettype wire

