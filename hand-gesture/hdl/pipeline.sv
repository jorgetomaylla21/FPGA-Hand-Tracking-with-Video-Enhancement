`default_nettype none
`timescale 1ns/1ps

module pipeline #(
    parameter STAGES = 1,
    parameter WIDTH = 1
) (
    input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] data_pipe [STAGES-1:0];
    assign data_out = data_pipe[STAGES-1];

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // reset all registers
            for (int i=0; i<STAGES; i++) begin
                data_pipe[i] <= 0;
            end

        end else begin
            // pipeline
            data_pipe[0] <= data_in;
            for (int i=1; i<STAGES; i++) begin
                data_pipe[i] <= data_pipe[i-1];
            end
        end
    end
endmodule

`default_nettype wire