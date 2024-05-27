`timescale 1ns / 1ps
`default_nettype none

//synchronizer module:
//This code takes in a signal not on the clk_in clock domain,
//runs it through SYNC_DEPTH flip flops on clk_in
//and outputs the signal
//s_out is therefore guaranteed (practically speaking) to be
//a signal existing on the clk_in domain and therefore chances
//of input timing violations should be minimal :)
module  synchronizer #(parameter SYNC_DEPTH = 2
                    ) (   input wire clk_in,
                          input wire rst_in,
                          input wire us_in, //unsync_in
                          output logic s_out); //sync_out

  logic [SYNC_DEPTH-1:0] sync;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      sync <= {(SYNC_DEPTH){us_in}};
    end else begin
      sync[SYNC_DEPTH-1] <= us_in;
      for (int i=1; i<SYNC_DEPTH; i= i+1)begin
        sync[i-1] <= sync[i];
      end
    end
  end
  assign s_out = sync[0];
endmodule

`default_nettype wire