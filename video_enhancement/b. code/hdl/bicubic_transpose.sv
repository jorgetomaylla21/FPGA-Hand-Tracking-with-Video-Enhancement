`default_nettype none
`timescale 1ns/1ps

module bicubic_transpose (
    input wire [5:0] p_in [3:0][3:0],
    output logic [5:0] p_ver [3:0][3:0],
    output logic [5:0] p_hor [3:0][3:0],
    output logic [5:0] p_ver_hor [3:0][3:0],
    output logic [5:0] p_trans [3:0][3:0],
    output logic [5:0] p_trans_ver [3:0][3:0]
);

	// (0, 0) transpose
	assign p_ver[0][0] = p_in[3][0];
	assign p_hor[0][0] = p_in[0][3];
	assign p_ver_hor[0][0] = p_in[3][3];
	assign p_trans[0][0] = p_in[0][0];
	assign p_trans_ver[0][0] = p_in[3][0];

	// (0, 1) transpose
	assign p_ver[0][1] = p_in[3][1];
	assign p_hor[0][1] = p_in[0][2];
	assign p_ver_hor[0][1] = p_in[3][2];
	assign p_trans[0][1] = p_in[1][0];
	assign p_trans_ver[0][1] = p_in[2][0];

	// (0, 2) transpose
	assign p_ver[0][2] = p_in[3][2];
	assign p_hor[0][2] = p_in[0][1];
	assign p_ver_hor[0][2] = p_in[3][1];
	assign p_trans[0][2] = p_in[2][0];
	assign p_trans_ver[0][2] = p_in[1][0];

	// (0, 3) transpose
	assign p_ver[0][3] = p_in[3][3];
	assign p_hor[0][3] = p_in[0][0];
	assign p_ver_hor[0][3] = p_in[3][0];
	assign p_trans[0][3] = p_in[3][0];
	assign p_trans_ver[0][3] = p_in[0][0];

	// (1, 0) transpose
	assign p_ver[1][0] = p_in[2][0];
	assign p_hor[1][0] = p_in[1][3];
	assign p_ver_hor[1][0] = p_in[2][3];
	assign p_trans[1][0] = p_in[0][1];
	assign p_trans_ver[1][0] = p_in[3][1];

	// (1, 1) transpose
	assign p_ver[1][1] = p_in[2][1];
	assign p_hor[1][1] = p_in[1][2];
	assign p_ver_hor[1][1] = p_in[2][2];
	assign p_trans[1][1] = p_in[1][1];
	assign p_trans_ver[1][1] = p_in[2][1];

	// (1, 2) transpose
	assign p_ver[1][2] = p_in[2][2];
	assign p_hor[1][2] = p_in[1][1];
	assign p_ver_hor[1][2] = p_in[2][1];
	assign p_trans[1][2] = p_in[2][1];
	assign p_trans_ver[1][2] = p_in[1][1];

	// (1, 3) transpose
	assign p_ver[1][3] = p_in[2][3];
	assign p_hor[1][3] = p_in[1][0];
	assign p_ver_hor[1][3] = p_in[2][0];
	assign p_trans[1][3] = p_in[3][1];
	assign p_trans_ver[1][3] = p_in[0][1];

	// (2, 0) transpose
	assign p_ver[2][0] = p_in[1][0];
	assign p_hor[2][0] = p_in[2][3];
	assign p_ver_hor[2][0] = p_in[1][3];
	assign p_trans[2][0] = p_in[0][2];
	assign p_trans_ver[2][0] = p_in[3][2];

	// (2, 1) transpose
	assign p_ver[2][1] = p_in[1][1];
	assign p_hor[2][1] = p_in[2][2];
	assign p_ver_hor[2][1] = p_in[1][2];
	assign p_trans[2][1] = p_in[1][2];
	assign p_trans_ver[2][1] = p_in[2][2];

	// (2, 2) transpose
	assign p_ver[2][2] = p_in[1][2];
	assign p_hor[2][2] = p_in[2][1];
	assign p_ver_hor[2][2] = p_in[1][1];
	assign p_trans[2][2] = p_in[2][2];
	assign p_trans_ver[2][2] = p_in[1][2];

	// (2, 3) transpose
	assign p_ver[2][3] = p_in[1][3];
	assign p_hor[2][3] = p_in[2][0];
	assign p_ver_hor[2][3] = p_in[1][0];
	assign p_trans[2][3] = p_in[3][2];
	assign p_trans_ver[2][3] = p_in[0][2];

	// (3, 0) transpose
	assign p_ver[3][0] = p_in[0][0];
	assign p_hor[3][0] = p_in[3][3];
	assign p_ver_hor[3][0] = p_in[0][3];
	assign p_trans[3][0] = p_in[0][3];
	assign p_trans_ver[3][0] = p_in[3][3];

	// (3, 1) transpose
	assign p_ver[3][1] = p_in[0][1];
	assign p_hor[3][1] = p_in[3][2];
	assign p_ver_hor[3][1] = p_in[0][2];
	assign p_trans[3][1] = p_in[1][3];
	assign p_trans_ver[3][1] = p_in[2][3];

	// (3, 2) transpose
	assign p_ver[3][2] = p_in[0][2];
	assign p_hor[3][2] = p_in[3][1];
	assign p_ver_hor[3][2] = p_in[0][1];
	assign p_trans[3][2] = p_in[2][3];
	assign p_trans_ver[3][2] = p_in[1][3];

	// (3, 3) transpose
	assign p_ver[3][3] = p_in[0][3];
	assign p_hor[3][3] = p_in[3][0];
	assign p_ver_hor[3][3] = p_in[0][0];
	assign p_trans[3][3] = p_in[3][3];
	assign p_trans_ver[3][3] = p_in[0][3];

endmodule

`default_nettype wire