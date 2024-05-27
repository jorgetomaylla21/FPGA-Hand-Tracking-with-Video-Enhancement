`default_nettype none
`timescale 1ns/1ps

module hand_signal_decoder #(
    parameter FILTERED_WIDTH = 131,
    parameter FRAME_WIDTH = 240,
    parameter FRAME_HEIGHT = 320
)(
    input wire clk_in,
    input wire new_data_in,
    input wire [3:0] data_in,
    output logic [10:0] h_offset,
    output logic [9:0] v_offset,
    output logic [2:0] filter_mode
);
    localparam SHIFT_SIZE = 1;
    logic [3:0] prev_data_in;

    always_ff @(posedge clk_in) begin
        if (new_data_in) begin
            prev_data_in <= data_in;
            case (data_in)
                4'd1: begin     // Up
                    if (v_offset > SHIFT_SIZE) 
                        v_offset <= v_offset - SHIFT_SIZE;
                end
                4'd2: begin     // Down
                    if (v_offset + FILTERED_WIDTH + SHIFT_SIZE < FRAME_HEIGHT)
                        v_offset <= v_offset + SHIFT_SIZE;
                end
                4'd3: begin     // Left
                    if (h_offset > SHIFT_SIZE) 
                        h_offset <= h_offset - SHIFT_SIZE;
                end
                4'd4: begin     // Right
                    if (h_offset + FILTERED_WIDTH + SHIFT_SIZE < FRAME_WIDTH)
                        h_offset <= h_offset + SHIFT_SIZE;
                end
                4'd5: begin     // Change Filter
                    if (prev_data_in != 4'd5) begin
                        filter_mode <= (filter_mode == 4)? 3'b0: filter_mode + 1;
                    end
                end
                // for other cases, do nothing (including signal 0 == nothing)
            endcase;
        end
    end
endmodule

`default_nettype wire