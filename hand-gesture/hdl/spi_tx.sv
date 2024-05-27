`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module spi_tx
       #(   parameter DATA_WIDTH = 8,
            parameter DATA_PERIOD = 100
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire [DATA_WIDTH-1:0] data_in,
          input wire trigger_in,
          output logic data_out,
          output logic data_clk_out,
          output logic sel_out
        );
  localparam HALF_PERIOD = int($floor(DATA_PERIOD/2));
  logic [$clog2(HALF_PERIOD*2)-1:0] period_counter; // counts up to data_period
  logic [$clog2(DATA_WIDTH)-1:0] counter; // counts which digit should be out
  logic [DATA_WIDTH-1:0] stored_data;
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        counter <= 0;
        period_counter <= 0;
        sel_out <= 1;
    end else begin
        if (!sel_out) begin //active
            // end of one digit transmission period
            if (period_counter == HALF_PERIOD * 2 - 1) begin
                // finished everything
                if (counter == DATA_WIDTH-1) begin
                    sel_out <= 1;

                // one digit finished, move to next digit
                end else begin
                    counter <= counter + 1;
                    period_counter <= 0;
                    stored_data <= {stored_data[DATA_WIDTH-2:0], 1'b0};

                    data_clk_out <= 0;
                    data_out <= stored_data[DATA_WIDTH-1];
                end

            // normal data_out cycles
            end else begin
                period_counter <= period_counter + 1;

                // If reached half of the single digit cycle
                if (period_counter == HALF_PERIOD -1) begin
                    data_clk_out <= 1;
                end
            end

        end else if (trigger_in) begin // unactive and triggered
            stored_data <= {data_in[DATA_WIDTH-2:0],1'b0};
            period_counter <= 0;
            counter <= 0;
            
            data_out <= data_in[DATA_WIDTH-1];
            data_clk_out <= 0; 
            sel_out <= 0; //activate
        end
    end
  end

endmodule //spi_tx

`default_nettype wire // prevents system from inferring an undeclared logic (good practice)