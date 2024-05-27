`default_nettype none
`timescale 1ns/1ps

module pixel_shift #(
    parameter WIDTH = 16,
    parameter HOR_SIZE = 4,
    parameter VER_SIZE = 4
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire  [WIDTH-1:0] pixel_in,
    output logic [WIDTH-1:0] pixel_array_out [HOR_SIZE-1:0][VER_SIZE-1:0],
    output logic valid_out
);
    logic [$clog2(HOR_SIZE)-1:0] h_counter;
    logic [$clog2(VER_SIZE)-1:0] v_counter;

    always_ff @(posedge clk_in) begin
        if (rst_in || !valid_in) begin
            h_counter   <= 0;
            v_counter   <= 0;
            valid_out   <= 0;

        end else begin
            // Shift pixels in column-major order
            for (int i=0; i<HOR_SIZE; i=i+1) begin
                for (int j=0; j<VER_SIZE-1; j=j+1) begin
                    pixel_array_out[i][j] <= pixel_array_out[i][j+1];
                end
            end
            for (int i=0; i<HOR_SIZE-1; i=i+1) begin
                pixel_array_out[i][VER_SIZE -1] <= pixel_array_out[i+1][0];
            end
            // Last pixel is inherited from input pixel
            pixel_array_out[HOR_SIZE-1][VER_SIZE-1] <= pixel_in;

            if (v_counter == VER_SIZE - 1) begin
                v_counter <= 0;
                if (h_counter != HOR_SIZE -1) begin
                    h_counter <= h_counter + 1;

                end else begin
                    // finished a column & enough pixels to start convolution -> valid
                    valid_out <= 1'b1;
                end

            end else begin
                valid_out <= 1'b0;
                v_counter <= v_counter + 1;
            end
        end
    end

endmodule

`default_nettype wire