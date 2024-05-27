`timescale 1ns / 1ps
`default_nettype none

module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);

  //your design here!
  localparam COUNTING = 0;
  localparam DIVIDING = 1;
  localparam START = 0;
  localparam WAITING = 1;
  
  logic [1:0] state;
  logic minor_state;
  logic [31:0] x_sum, y_sum;
  logic [19:0] pixel_total;
  logic [10:0] x_quotient;
  logic [9:0] y_quotient;
  logic x_valid_in, y_valid_in, x_valid_out, y_valid_out;
  logic xcom_ready, ycom_ready;

  divider xdivider(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(x_sum),
    .divisor_in(pixel_total),
    .data_valid_in(x_valid_in),
    .quotient_out(x_quotient),
    .data_valid_out(x_valid_out)
  );

   divider ydivider(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(y_sum),
    .divisor_in(pixel_total),
    .data_valid_in(y_valid_in),
    .quotient_out(y_quotient),
    .data_valid_out(y_valid_out)
  );

  always_ff @(posedge clk_in ) begin
    if (rst_in) begin
      valid_out <= 0;
      x_out <= 0;
      y_out <= 0;
      state <= COUNTING;
      minor_state <= 0;
      x_sum <= 0;
      y_sum <= 0;
      pixel_total <= 0;
      x_valid_in <= 0;
      y_valid_in <= 0;
      xcom_ready <= 0;
      ycom_ready <= 0;
    end else begin
      case (state)
        COUNTING: begin
          if (tabulate_in) begin
            //do we add the current xin and yin when tabulate_in is called? Yes
            if (valid_in) begin
              //tally up pixels and running x and y sum
              x_sum <= x_sum + x_in;
              y_sum <= y_sum + y_in;
              pixel_total <= pixel_total + 1;
            end
            if (pixel_total > 0) begin
              state <= DIVIDING;
            end
          end else begin
            if (valid_in) begin
              //tally up pixels and running x and y sum
              x_sum <= x_sum + x_in;
              y_sum <= y_sum + y_in;
              pixel_total <= pixel_total + 1;
            end
          end
          

        end
        DIVIDING: begin
          case(minor_state) 
            START: begin
              x_valid_in <= 1;
              y_valid_in <= 1;
              minor_state <= WAITING;
            end
            WAITING: begin
              x_valid_in <= 0;  //no more valid divisions
              y_valid_in <= 0;
              if (x_valid_out) begin
                x_out <= x_quotient;  //we can put it in output because valid_out still 0
                xcom_ready <= 1;
              end
              if (y_valid_out) begin
                y_out <= y_quotient;
                ycom_ready <= 1;
              end
              if (xcom_ready && ycom_ready) begin
                valid_out <= 1;
                state <= 2; //to exit division
              end
            end
          endcase
        end
        default: begin
          //reset values
          valid_out <= 0;
          x_out <= 0;
          y_out <= 0;
          state <= COUNTING;
          minor_state <= 0;
          x_sum <= 0;
          y_sum <= 0;
          pixel_total <= 0;
          x_valid_in <= 0;
          y_valid_in <= 0;
          xcom_ready <= 0;
          ycom_ready <= 0;
          

        end
      endcase
      
    end
  end


endmodule




`default_nettype wire
