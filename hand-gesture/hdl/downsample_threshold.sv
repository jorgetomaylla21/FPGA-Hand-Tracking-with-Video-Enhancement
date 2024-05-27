`default_nettype none
`timescale 1ns/1ps

module downsample_threshold #(
    parameter FILTER_SIZE = 5,
    parameter CAM_WIDTH = 240,
    parameter CAM_HEIGHT = 320
) (
    input wire clk_in,
    input wire valid_ds_in,
    input wire [$clog2(FILTER_AREA)-1:0] threshold_ds_in,
    input wire mask_in,

    output logic mask_ds_out,
    output logic [10:0] hcount_write_out,
    output logic [9:0] vcount_write_out,
    output logic valid_mask_out
);
    localparam DOWNSAMPLED_WIDTH = $rtoi($floor(CAM_WIDTH / FILTER_SIZE));
    localparam DOWNSAMPLED_HEIGHT = $rtoi($floor(CAM_HEIGHT / FILTER_SIZE));
    localparam FILTER_AREA = FILTER_SIZE*FILTER_SIZE;

    logic [$clog2(FILTER_AREA)-1:0] step_counter, mask_counter;

    always_ff @(posedge clk_in) begin

        // End of Frame Informed
        if (!valid_ds_in) begin
            step_counter <= 0;
            mask_counter <= 0;
            valid_mask_out <= 0;
            hcount_write_out <= 0;
            vcount_write_out <= 0;

        end else if (valid_ds_in) begin
            step_counter <= (step_counter == FILTER_AREA -1)? 0 : step_counter + 1'b1;

            // Case 1: End of the current filter
            if (step_counter == FILTER_AREA -1) begin
                valid_mask_out <= 1'b1;
                mask_ds_out <= (mask_counter + mask_in >= threshold_ds_in);
                mask_counter <= 0;

            // Otherwise, update mask_counter
            end else begin
                valid_mask_out <= 1'b0;
                mask_counter <= mask_counter + mask_in;

                // Update BRAM writing address (for next patch)
                if (valid_mask_out) begin
                    if (hcount_write_out == DOWNSAMPLED_WIDTH -1) begin
                        hcount_write_out <= 0;
                        vcount_write_out <= vcount_write_out + 1'b1;
                    end else begin
                        hcount_write_out <= hcount_write_out + 1'b1;
                    end
                end

            end
        end
    end

endmodule

`default_nettype wire