`default_nettype none
`timescale 1ns/1ps

// Clip the result of convolution within [0, 255] range
// There are two cases of overflow, negative numbers or numbers bigger than 255,
// where their top two MSBs are used to distinguish between these cases effectively.
// 'b10: bigger than 255
// 'b11: negative number

module value_clip #(
    parameter WIDTH = 9
) (
    input wire clk_in,
    input wire [WIDTH-1:0] data_in,
    output logic [WIDTH-2:0] data_out
);
    localparam MAX_OUT = 2**(WIDTH-1) - 1;

    always_ff @(posedge clk_in) begin
        case (data_in[WIDTH-1:WIDTH-2])
            2'b10:  data_out <= MAX_OUT;
            2'b11:  data_out <= 0;
            default:data_out <= data_in;
        endcase
    end
endmodule

`default_nettype wire