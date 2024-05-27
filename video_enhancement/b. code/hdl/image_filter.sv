`default_nettype none
`timescale 1ns/1ps

module image_filter (
    input wire clk_in,
    input wire valid_in,
    input wire [2:0] filter_mode_in,
    input wire [1:0] color_channel_in,
    input wire [15:0] unfiltered_in [2:0][2:0],
    output logic valid_out,
    output logic [15:0] filtered_out
);
    logic [5:0] r_in [2:0][2:0], g_in [2:0][2:0], b_in [2:0][2:0];
    logic [5:0] r_out, g_out, b_out;

    // multiplex output by color channel selection
    always_comb begin
        case (color_channel_in)
            2'b00: filtered_out = {r_out[5:1], g_out, b_out[5:1]};  // (r, g, b)
            2'b01: filtered_out = {r_out[5:1], 6'b0, 5'b0};         // (r, 0, 0)
            2'b10: filtered_out = {5'b0, g_out, 5'b0};              // (0, g, 0)
            2'b11: filtered_out = {5'b0, 6'b0, b_out[5:1]};         // (0, 0, b)
            default: filtered_out = 16'b0;
        endcase;
    end

    // bit selection for r, g, b
    genvar i, j;
    generate
        for (i=0; i<3; i=i+1) begin
            for (j=0; j<3; j=j+1) begin
                assign r_in[i][j] = {unfiltered_in[i][j][15:11], 1'b0};
                assign g_in[i][j] = unfiltered_in[i][j][10:5];
                assign b_in[i][j] = {unfiltered_in[i][j][4:0], 1'b0};
            end
        end
    endgenerate

    // Total 4-Staged Pipeline
    pipeline #(
        .STAGES(4),
        .WIDTH(1)
    ) image_filter_pipe (
        .clk_in(clk_in),
        .rst_in(),
        .data_in(valid_in),
        .data_out(valid_out)
    );

    single_channel_filter red_filter (
        .clk_in(clk_in),
        .filter_mode_in(filter_mode_in),
        .p_in(r_in),
        .p_out(r_out)
    );
    single_channel_filter green_filter (
        .clk_in(clk_in),
        .filter_mode_in(filter_mode_in),
        .p_in(g_in),
        .p_out(g_out)
    );
    single_channel_filter blue_filter (
        .clk_in(clk_in),
        .filter_mode_in(filter_mode_in),
        .p_in(b_in),
        .p_out(b_out)
    );

endmodule

module single_channel_filter (
    input wire clk_in,
    input wire [2:0] filter_mode_in,
    input wire [5:0] p_in [2:0][2:0],
    output logic [5:0] p_out
);
    logic [6:0] pos_filtered, neg_filtered;
    logic [7:0] p_unclipped;
    assign p_unclipped = pos_filtered - neg_filtered;

    nonnegative_image_filter positive_image_filter (
        .clk_in(clk_in),
        .positive_mode(1'b1), // Calculate Positive Parts of the Coefficient
        .filter_mode_in(filter_mode_in),
        .p_in(p_in),
        .p_out(pos_filtered)
    );
    nonnegative_image_filter negative_image_filter(
        .clk_in(clk_in),
        .positive_mode(1'b0), // Calculate Negative Parts of the Coefficient
        .filter_mode_in(filter_mode_in),
        .p_in(p_in),
        .p_out(neg_filtered)
    );

    always_ff @(posedge clk_in) begin
        if (neg_filtered > pos_filtered) begin
            p_out <= 6'b0;
        end else if (p_unclipped > 8'd63) begin
            p_out <= 6'd63;
        end else begin
            p_out <= p_unclipped;
        end
    end

endmodule

module nonnegative_image_filter (
    input wire clk_in,
    input wire positive_mode,
    input wire [2:0] filter_mode_in,
    input wire [5:0] p_in [2:0][2:0],
    output logic [6:0] p_out
);
    logic [6:0] filter [2:0][2:0];
    logic [12:0] p_mult [2:0][2:0];
    logic [14:0] p_add [2:0];
    logic [6:0]  p_filtered;

    always_ff @(posedge clk_in) begin

        // Step 1: Multiply by filter
        for (int i=0; i<3; i=i+1) begin
            for (int j=0; j<3; j=j+1) begin
                p_mult[i][j] <= filter[i][j] * p_in[i][j];
            end 
        end

        // Step 2: Intermediate Add step
        p_add[0] <= p_mult[0][0] + p_mult[0][1] + p_mult[0][2];
        p_add[1] <= p_mult[1][0] + p_mult[1][1] + p_mult[1][2];
        p_add[2] <= p_mult[2][0] + p_mult[2][1] + p_mult[2][2];

        // Step 3: Final Add
        p_out <= (filter_mode_in == 3'b010)? (p_add[0] + p_add[1] + p_add[2])>>4 : (p_add[0] + p_add[1] + p_add[2])>>5;

        // Filter updated according to the selected channel ( positive filter )
        if (positive_mode == 1'b1) begin
            case (filter_mode_in)
            3'b000: begin
                // Original Pixel
                filter[0][0] <= 0;
                filter[0][1] <= 0;
                filter[0][2] <= 0;
                filter[1][0] <= 0;
                filter[1][1] <= 32;
                filter[1][2] <= 0;
                filter[2][0] <= 0;
                filter[2][1] <= 0;
                filter[2][2] <= 0;
            end
            3'b001: begin
                // Gaussian
                filter[0][0] <= 2;
                filter[0][1] <= 4;
                filter[0][2] <= 2;
                filter[1][0] <= 4;
                filter[1][1] <= 8;
                filter[1][2] <= 4;
                filter[2][0] <= 2;
                filter[2][1] <= 4;
                filter[2][2] <= 2;
            end
            3'b010: begin
                // Sharpening (f=0.5)
                filter[0][0] <= 0;
                filter[0][1] <= 0;
                filter[0][2] <= 0;
                filter[1][0] <= 0;
                filter[1][1] <= 32;
                filter[1][2] <= 0;
                filter[2][0] <= 0;
                filter[2][1] <= 0;
                filter[2][2] <= 0;
            end
            3'b011: begin   
                // gradient_x
                filter[0][0] <= 0;
                filter[0][1] <= 0;
                filter[0][2] <= 16;
                filter[1][0] <= 0;
                filter[1][1] <= 0;
                filter[1][2] <= 32;
                filter[2][0] <= 0;
                filter[2][1] <= 0;
                filter[2][2] <= 16;
            end
            3'b100: begin
                // gradient_y
                filter[0][0] <= 0;
                filter[0][1] <= 0;
                filter[0][2] <= 0;
                filter[1][0] <= 0;
                filter[1][1] <= 0;
                filter[1][2] <= 0;
                filter[2][0] <= 16;
                filter[2][1] <= 32;
                filter[2][2] <= 16;
                end
            endcase;

        end else begin
        // Negative sign filter
            case (filter_mode_in)
            3'b000, 3'b001: begin
                // Original Pixel, Gaussian
                filter[0][0] <= 0;
                filter[0][1] <= 0;
                filter[0][2] <= 0;
                filter[1][0] <= 0;
                filter[1][1] <= 0;
                filter[1][2] <= 0;
                filter[2][0] <= 0;
                filter[2][1] <= 0;
                filter[2][2] <= 0;
            end
            3'b010: begin
                // Sharpening (f=0.5)
                filter[0][0] <= 1;
                filter[0][1] <= 2;
                filter[0][2] <= 1;
                filter[1][0] <= 2;
                filter[1][1] <= 4;
                filter[1][2] <= 2;
                filter[2][0] <= 1;
                filter[2][1] <= 2;
                filter[2][2] <= 1;
            end
            3'b011: begin   
                // gradient_x
                filter[0][0] <= 16;
                filter[0][1] <= 0;
                filter[0][2] <= 0;
                filter[1][0] <= 32;
                filter[1][1] <= 0;
                filter[1][2] <= 0;
                filter[2][0] <= 16;
                filter[2][1] <= 0;
                filter[2][2] <= 0;
            end
            3'b100: begin
                // gradient_y
                filter[0][0] <= 16;
                filter[0][1] <= 32;
                filter[0][2] <= 16;
                filter[1][0] <= 0;
                filter[1][1] <= 0;
                filter[1][2] <= 0;
                filter[2][0] <= 0;
                filter[2][1] <= 0;
                filter[2][2] <= 0;
            end
            endcase;
        end
    end 
endmodule

`default_nettype wire