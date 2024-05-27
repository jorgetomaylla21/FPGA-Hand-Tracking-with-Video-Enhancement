`default_nettype none
`timescale 1ns/1ps

// array([[0, -9, 0, 0], 
//        [0, 111, 0, 0], 
//        [0, 29, 0, 0], 
//        [0, -3, 0, 0]])/128
module kernel_1 (
    input wire clk_in,
    input wire [5:0] p1,
    input wire [5:0] p2,
    input wire [5:0] p3,
    input wire [5:0] p4,
    output logic [8:0] pixel_out
);
    // Intermediate values (Step 1, 2)
    logic [12:0] m1, m2, m3, m4;
    logic [13:0] pos, neg;

    // Unify kernels with 4 pipeline stages
    logic [8:0] pixel_out_pipe;

    always_ff @(posedge clk_in) begin
        // Step 1: constant multiplications
        m1 <= (p1 << 3) + p1;               // 9    = 8 + 1
        m2 <= (p2 << 7) - (p2 << 4) - p2;   // 111  = 128 - 16 - 1
        m3 <= (p3 << 5) - (p3 << 1) - p3;   // 29   = 32 - 2 - 1
        m4 <= (p4 << 1) + p4;               // 3    = 2 + 1

        // Step 2: Intermediate Addition
        pos <= m2 + m3;
        neg <= m1 + m4;

        // Step 3: Pipeline stage 3
        pixel_out_pipe <= (pos- neg) >> 5;  // (8-6) - log(128)

        // Step 4: Pipeline stage 4 (Result)
        pixel_out <= pixel_out_pipe;
    end
endmodule

// array([[0, -1, 0, 0], 
//        [0, 9, 0, 0], 
//        [0, 9, 0, 0], 
//        [0, -1, 0, 0]])/16
module kernel_2 (
    input wire clk_in,
    input wire [5:0] p1,
    input wire [5:0] p2,
    input wire [5:0] p3,
    input wire [5:0] p4,
    output logic [8:0] pixel_out
);
    logic [6:0] m14;
    logic [9:0] m2, m3;
    logic [10:0] pos, neg;

    // Unify kernels with 4 pipeline stages
    logic [8:0] pixel_out_pipe;

    always_ff @(posedge clk_in) begin
        // Step 1: constant multiplications
        m14 <= p1 + p4;
        m2 <= (p2 << 3) + p2;   // 9 = 8 + 1
        m3 <= (p3 << 3) + p3;   

        // Step 2: Intermediate Addition
        pos <= m2 + m3;
        neg <= m14;

        // Step 3: Pipeline stage 3
        pixel_out_pipe <= (pos - neg) >> 2;  // (8-6) - log(16)

        // Step 4: Pipeline stage 4 (Result)
        pixel_out <= pixel_out_pipe;
    end
endmodule

// target pixel is transposed to be closest to the left-right corner (of conv. patch)
// array([[  3, -31,  -8,   0],
//        [-31, 385, 101, -10],
//        [ -8, 101,  26,  -3],
//        [  0, -10,  -3,   0]])/2**9
module kernel_3 (
    input wire clk_in,
    input wire [5:0] p [3:0][3:0],
    output logic [8:0] pixel_out
);
    // Initial after constant multiplication
    logic [9:0] m00, m13, m23, m31, m32;
    logic [10:0] m02_20_pipe1, m02_20_pipe2;
    logic [14:0] m01, m10, m11, m12, m21, m22;

    // Intermediate groups (Step 2, 3)
    logic [11:0] neg_23_32_31;
    logic [12:0] neg_01_10_13;
    logic [14:0] pos_00_12_21, neg_all;
    logic [15:0] pos_11_22, pos_all;

    always_ff @(posedge clk_in) begin
        // Step 1: constant multiplications
        m00 <= (p[0][0] << 1) + p[0][0];            // 3
        m01 <= (p[0][1] << 5) - p[0][1];            // 31
        m02_20_pipe1 <= (p[0][2] + p[2][0])<<3;           // 8 * (p02 + p20) (Is this safe?)
        m10 <= (p[1][0] << 5) - p[1][0];            // 31
        m11 <= (p[1][1] << 8) + (p[1][1] << 7) + p[1][1]; // 385 = 256 + 128 + 1
        m12 <= 101 * p[1][2];                       // 101
        m13 <= (p[1][3] << 3) + (p[1][3] << 1);     // 10 = 8 + 1
        m21 <= 101 * p[2][1];                       // 101
        m22 <= (p[2][2] << 4) + (p[2][2] << 3) + (p[2][2] << 1); // 26 = 16 + 8 + 2
        m23 <= (p[2][3] << 1) + p[2][3];            // 3
        m31 <= (p[3][1] << 3) + (p[3][1] << 1);     // 10
        m32 <= (p[3][2] << 1) + p[3][2];            // 3

        // Step 2: Additions
        neg_01_10_13 <= m01 + m10 + m13;
        neg_23_32_31 <= m23 + m32 + m31;
        pos_00_12_21 <= m00 + m12 + m21;
        pos_11_22 <= m11 + m22;
        m02_20_pipe2 <= m02_20_pipe1;

        // Step 3: Intermediate add
        pos_all <= pos_00_12_21 + pos_11_22;
        neg_all <= neg_01_10_13 + neg_23_32_31 + m02_20_pipe2;

        // Step 4: Result
        pixel_out <= (pos_all - neg_all) >> 7;
    end
endmodule



// array([[  2, -28,  -7,   1],
//        [-20, 250,  65,  -7],
//        [-20, 250,  65,  -7],
//        [  2, -28,  -7,   1]])/2**9
module kernel_4 (
    input wire clk_in,
    input wire [5:0] p [3:0][3:0],
    output logic [8:0] pixel_out
);
    logic [6:0] sum [1:0][3:0];
    logic [8:0] pos_00_03;
    logic [14:0] neg_01, neg_02, neg_10, pos_11, pos_12, neg_13;
    logic [14:0] neg_1, neg_2;
    logic [15:0] pos;

    always_ff @(posedge clk_in) begin
        // Step 1: add vertically symmetric pairs first
        for (int i=0; i<2; i=i+1) begin
            for (int j=0; j<4; j=j+1) begin
                sum[i][j] <= p[i][j] + p[3-i][j];
            end
        end

        // Step 2: multiply constants
        pos_00_03 <= (sum[0][0] << 1) + sum[0][3];
        neg_01 <= (sum[0][1] << 5) - (sum[0][1] << 2);  // 28 = 32 - 4
        neg_02 <= (sum[0][2] << 3) - sum[0][2];         // 7  = 8 - 1
        neg_10 <= (sum[1][0] << 4) + (sum[1][0] << 2);  // 20 = 16 + 4
        pos_11 <= (sum[1][1] << 8) - (sum[1][1] << 2) - (sum[1][1] << 1); // 250 = 256 - 4 - 2
        pos_12 <= (sum[1][2] << 6) + sum[1][2];         // 65 = 64 + 1
        neg_13 <= (sum[1][3] << 3) - sum[1][3];         // 7  = 8 - 1

        // Step 3: Intermediate add
        pos <= pos_11 + pos_12 + pos_00_03;
        neg_1 <= neg_01 + neg_02;
        neg_2 <= neg_10 + neg_13;

        // Step 4: Result
        pixel_out <= (pos - neg_1 - neg_2) >>7; // (8 - 6) - log(512) = -7
    end
endmodule


// array([[1, -9, -9, 1], 
//        [-9, 81, 81, -9], 
//        [-9, 81, 81, -9], 
//        [1, -9, -9, 1]])/256
module kernel_5 (
    input wire clk_in,
    input wire [5:0] p [3:0][3:0],
    output logic [8:0] pixel_out
);
    logic [6:0] sum [1:0][3:0];
    logic [7:0] sum_2 [1:0][1:0];
    logic [11:0] neg_1, neg_2;
    logic [14:0] pos;

    always_ff @(posedge clk_in) begin
        // Step 1: add vertically symmetric pairs first
        for (int i=0; i<2; i=i+1) begin
            for (int j=0; j<4; j=j+1) begin
                sum[i][j] <= p[i][j] + p[3-i][j];
            end
        end

        // Step 2: add horizontally symmetric pairs
        for (int i=0; i<2; i=i+1) begin
            for (int j=0; j<2; j=j+1) begin
                sum_2[i][j] <= sum[i][j] + sum[i][3-j];
            end
        end
    
        // Step 3: Intermediate addition
        neg_1 <= (sum_2[0][1] << 3) + sum_2[0][1] - sum_2[0][0];    // 9*[] - 1*[]
        neg_2 <= (sum_2[1][0] << 3) + sum_2[1][0];
        pos   <= (sum_2[1][1] << 6) + (sum_2[1][1] << 4) + sum_2[1][1]; // 81 = 64 + 16 + 1

        // Step 4: Result
        pixel_out <= (pos - neg_1 - neg_2) >> 6; // 2- log(256)
    end
endmodule

`default_nettype wire