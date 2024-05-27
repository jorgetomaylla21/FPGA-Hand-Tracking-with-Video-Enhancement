`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module spi_rx
       #(  parameter DATA_WIDTH = 10
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire data_in,
          input wire data_clk_in,
          input wire sel_in,
          output logic [DATA_WIDTH-1:0] data_out,
          output logic new_data_out
        );

    logic [DATA_WIDTH-1:0] streamed_data;
    logic [$clog2(DATA_WIDTH)-1:0] counter;
    logic prev_data_clk;

    always_ff @(posedge clk_in) begin
        prev_data_clk <= data_clk_in;

        // reset
        if (sel_in) begin
            streamed_data <= 0;
            counter <= 0;
            data_out <= 0;
            new_data_out <= 0;

        end else begin
            if (new_data_out) begin
                new_data_out <= 0;

            // rising edge of data_clk_in, store a bit
            end else if (!prev_data_clk && data_clk_in) begin
                // If all digits are gathered, data out
                if (counter == DATA_WIDTH-1) begin
                    data_out <= {streamed_data[DATA_WIDTH-2:0], data_in};
                    new_data_out <= 1;
                end 

                streamed_data <= {streamed_data[DATA_WIDTH-2:0], data_in};
                counter <= counter + 1;
            end
        end
    end

endmodule

`default_nettype wire // prevents system from inferring an undeclared logic (good practice)
