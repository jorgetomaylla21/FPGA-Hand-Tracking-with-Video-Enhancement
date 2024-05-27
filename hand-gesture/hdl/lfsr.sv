`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module lfsr_16 ( input wire clk_in, input wire rst_in,
                    input wire [15:0] seed_in,
                    output logic [15:0] q_out);
  logic [15:0] state;
    always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= seed_in;
    end else begin
      state <= {state[15] ^ state[14], state[13:2], state[15] ^ state[1], state[0], state[15]};
    end
  end
  assign q_out = state;
endmodule

`default_nettype wire