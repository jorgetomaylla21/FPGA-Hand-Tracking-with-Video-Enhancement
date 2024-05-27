`default_nettype none
`timescale 1ns/1ps

module bicubic_interpolation (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [15:0] pixel_array_in [3:0][3:0],
    output logic [7:0] r_out [3:0][3:0],
    output logic [7:0] g_out [3:0][3:0],
    output logic [7:0] b_out [3:0][3:0],
    output logic valid_out
);
    logic [5:0] r_in [3:0][3:0], g_in [3:0][3:0], b_in [3:0][3:0];

    // bit selection for r, g, b
    genvar i;
    genvar j;
    generate
        for (i=0; i<4; i=i+1) begin
            for (j=0; j<4; j=j+1) begin
                assign r_in[i][j] = {pixel_array_in[i][j][15:11], 1'b0};
                assign g_in[i][j] = pixel_array_in[i][j][10:5];
                assign b_in[i][j] = {pixel_array_in[i][j][4:0], 1'b0};
            end
        end
    endgenerate

    // pipeline valid bit; it is sufficient to reset only the valid bit 
    pipeline #(
        .STAGES(5),
        .WIDTH(1)) 
    valid_pipeline (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .data_in(valid_in),
      .data_out(valid_out));

    //Connect each R, G, B Channel to single channel convolution module
    single_channel_bicubic_interpolation red_bicubic_instance (
        .clk_in(clk_in),
        .p_in(r_in),
        .p_out(r_out)
    );
    
    single_channel_bicubic_interpolation green_bicubic_instance (
        .clk_in(clk_in),
        .p_in(g_in),
        .p_out(g_out)
    );
    single_channel_bicubic_interpolation blue_bicubic_instance (
        .clk_in(clk_in),
        .p_in(b_in),
        .p_out(b_out)
    );
endmodule

module single_channel_bicubic_interpolation (
    input wire clk_in,
    input wire [5:0] p_in [3:0][3:0],
    output logic [7:0] p_out [3:0][3:0]
);
    // Temporary state (unclipped within the range 0 to 255 (inclusive))
    logic [8:0] p_tmp [3:0][3:0];

    wire [5:0] p_ver [3:0][3:0], p_hor [3:0][3:0], p_trans [3:0][3:0];
    wire [5:0] p_ver_hor [3:0][3:0], p_trans_ver [3:0][3:0];

    // wires for combination of vertical, horizontal, and transposed flips
    bicubic_transpose transpose_instance (
        .p_in(p_in),
        .p_ver(p_ver),
        .p_hor(p_hor),
        .p_ver_hor(p_ver_hor),
        .p_trans(p_trans),
        .p_trans_ver(p_trans_ver)
    );

    // ======== CLIP RANGE ======== //
    //clip results in range [0, 255]
    genvar i;
    generate
        for (i=1; i<16; i=i+1) begin
            value_clip clip_instance (
                .clk_in(clk_in),
                .data_in(p_tmp[i/4][i%4]),
                .data_out(p_out[i/4][i%4])
            );
        end
    endgenerate

    // (0, 0)
    // Pipeline original pixel value
    pipeline #(
        .STAGES(5),
        .WIDTH(6)) 
    pixel_0_0_pipeline (
      .clk_in(clk_in),      
      .data_in(p_in[1][1]),
      .data_out(p_out[0][0][7:2])
    );
    assign p_out[0][0][1:0] = 2'b0;


    // ========== KERNEL ========== //
    // calculate (row, col) pixel_out

    // (1, 0)
    // Kernel 1
    kernel_1 pixel_1_0 (
        .clk_in(clk_in),
        .p1(p_in[0][1]),
        .p2(p_in[1][1]),
        .p3(p_in[2][1]),
        .p4(p_in[3][1]),
        .pixel_out(p_tmp[1][0])
    );

    // (2, 0)
    // Kernel 2
    kernel_2 pixel_2_0 (
        .clk_in(clk_in),
        .p1(p_in[0][1]),
        .p2(p_in[1][1]),
        .p3(p_in[2][1]),
        .p4(p_in[3][1]),
        .pixel_out(p_tmp[2][0])
    );

    // (3, 0)
    // Kernel 1 (vertical flip)
    kernel_1 pixel_3_0 (
        .clk_in(clk_in),
        .p1(p_in[3][1]),
        .p2(p_in[2][1]),
        .p3(p_in[1][1]),
        .p4(p_in[0][1]),
        .pixel_out(p_tmp[3][0])
    );

    // (0, 1)
    // Kernel 1 (transpose)
    kernel_1 pixel_0_1 (
        .clk_in(clk_in),
        .p1(p_in[1][0]),
        .p2(p_in[1][1]),
        .p3(p_in[1][2]),
        .p4(p_in[1][3]),
        .pixel_out(p_tmp[0][1])
    );

    // (1, 1)
    // Kernel 3
    kernel_3 pixel_1_1 (
        .clk_in(clk_in),
        .p(p_in),
        .pixel_out(p_tmp[1][1])
    );

    // (2, 1)
    // Kernel 4
    kernel_4 pixel_2_1 (
        .clk_in(clk_in),
        .p(p_in),
        .pixel_out(p_tmp[2][1])
    );

    // (3, 1)
    // Kernel 3 (vertical flip)
    kernel_3 pixel_3_1 (
        .clk_in(clk_in),
        .p(p_ver),
        .pixel_out(p_tmp[3][1])
    );
    
    // (0, 2)
    // Kernel 2 (transpose)
    kernel_2 pixel_0_2 (
        .clk_in(clk_in),
        .p1(p_in[1][0]),
        .p2(p_in[1][1]),
        .p3(p_in[1][2]),
        .p4(p_in[1][3]),
        .pixel_out(p_tmp[0][2])
    );

    // (1, 2)
    // Kernel 4 ((2, 1) transpose)
    kernel_4 pixel_1_2 (
        .clk_in(clk_in),
        .p(p_trans),
        .pixel_out(p_tmp[1][2])
    );

    // (2, 2)
    // Kernel 5
    kernel_5 pixel_2_2 (
        .clk_in(clk_in),
        .p(p_in),
        .pixel_out(p_tmp[2][2])
    );

    // (3, 2)
    // Kernel 4 (transpose and vertical flip)
    kernel_4 pixel_3_2 (
        .clk_in(clk_in),
        .p(p_trans_ver),
        .pixel_out(p_tmp[3][2])
    );

    // (0, 3)
    // Kernel 1 (transpose and horizontal flip)
    kernel_1 pixel_0_3 (
        .clk_in(clk_in),
        .p1(p_in[1][3]),
        .p2(p_in[1][2]),
        .p3(p_in[1][1]),
        .p4(p_in[1][0]),
        .pixel_out(p_tmp[0][3])
    );

    // (1, 3)
    // Kernel 3 (horizontal flip)
    kernel_3 pixel_1_3 (
        .clk_in(clk_in),
        .p(p_hor),
        .pixel_out(p_tmp[1][3])
    );

    // (2, 3)
    // Kernel 4 (horizontal flip)
    kernel_4 pixel_2_3 (
        .clk_in(clk_in),
        .p(p_hor),
        .pixel_out(p_tmp[2][3])
    );

    // (3, 3)
    // Kernel 3 (vertical and horizontal flip)
    kernel_3 pixel_3_3 (
        .clk_in(clk_in),
        .p(p_ver_hor),
        .pixel_out(p_tmp[3][3])
    );

endmodule

`default_nettype wire