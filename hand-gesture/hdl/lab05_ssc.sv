`timescale 1ns / 1ps
`default_nettype none

module lab05_ssc #(parameter COUNT_TO = 100000)
                                (   input wire         clk_in,
                                    input wire         rst_in,
                                    input wire [7:0]  lt_in,
                                    input wire [7:0]  ut_in,
                                    input wire [2:0]  channel_sel_in,
                                    output logic[6:0]   cat_out,
                                    output logic[7:0]   an_out
                                 );

  logic[7:0]      segment_state;
  logic[31:0]     segment_counter;
  logic [6:0]     led_out;

  logic [6:0] symbol_cat [1:0];
  always_comb begin
    case(channel_sel_in)
      3'b000: symbol_cat[0] = 7'b1101111; //g
      3'b001: symbol_cat[0] = 7'b1010000; //r
      3'b010: symbol_cat[0] = 7'b1111100; //b
      3'b011: symbol_cat[0] = 7'b0000000; //null
      3'b100: symbol_cat[0] = 7'b1101110; //y
      3'b101: symbol_cat[0] = 7'b1010000; //r (Cr)
      3'b110: symbol_cat[0] = 7'b1111100; //b (Cb)
      3'b111: symbol_cat[0] = 7'b0000000; //null
    endcase
  end

  always_comb begin
    case(channel_sel_in)
      3'b000: symbol_cat[1] = 7'b0000000; //g
      3'b001: symbol_cat[1] = 7'b0000000; //r
      3'b010: symbol_cat[1] = 7'b0000000; //b
      3'b011: symbol_cat[1] = 7'b0000000; //null
      3'b100: symbol_cat[1] = 7'b0000000; //y
      3'b101: symbol_cat[1] = 7'b0111001; //C (Cr)
      3'b110: symbol_cat[1] = 7'b0111001; //C (Cb)
      3'b111: symbol_cat[1] = 7'b0000000; //null
    endcase
  end

  assign cat_out = ~led_out;
  assign an_out = ~segment_state;

  always_comb begin
    case(segment_state)
      8'b0000_0001:   led_out = symbol_cat[0];
      8'b0000_0010:   led_out = symbol_cat[1];
      8'b0000_0100:   led_out = 7'b0000000;
      8'b0000_1000:   led_out = bto7s_led_out;
      8'b0001_0000:   led_out = bto7s_led_out;
      8'b0010_0000:   led_out = 7'b0000000;
      8'b0100_0000:   led_out = bto7s_led_out;
      8'b1000_0000:   led_out = bto7s_led_out;
      default:        led_out = 7'b0000000;
    endcase
  end

  always_comb begin
    case(segment_state)
      8'b0000_0001:   routed_vals = 4'b0;
      8'b0000_0010:   routed_vals = 4'b0;
      8'b0000_0100:   routed_vals = 4'b0;
      8'b0000_1000:   routed_vals = lt_in[3:0];
      8'b0001_0000:   routed_vals = lt_in[7:4];
      8'b0010_0000:   routed_vals = 4'b0;
      8'b0100_0000:   routed_vals = ut_in[3:0];
      8'b1000_0000:   routed_vals = ut_in[7:4];
      default:        routed_vals = 4'b0;
    endcase
  end

  logic [3:0]     routed_vals;
  logic [6:0]     bto7s_led_out;

  bto7s mbto7s (.x_in(routed_vals), .s_out(bto7s_led_out));

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      segment_state <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_TO)begin
          segment_counter <= 32'd0;
          segment_state <= {segment_state[6:0],segment_state[7]};
      end else begin
          segment_counter <= segment_counter +1;
      end
    end
  end
endmodule //seven_segment_controller

module bto7s(
        input wire [3:0]   x_in,
        output logic [6:0] s_out);

        logic sa, sb, sc, sd, se, sf, sg;
        assign s_out = {sg, sf, se, sd, sc, sb, sa};

        // array of bits that are "one hot" with numbers 0 through 15
        logic [15:0] num;

        assign num[0] = ~x_in[3] && ~x_in[2] && ~x_in[1] && ~x_in[0];
        assign num[1] = ~x_in[3] && ~x_in[2] && ~x_in[1] && x_in[0];
        assign num[2] = x_in == 4'd2;
        assign num[3] = x_in == 4'd3;
        assign num[4] = x_in == 4'd4;
        assign num[5] = x_in == 4'd5;
        assign num[6] = x_in == 4'd6;
        assign num[7] = x_in == 4'd7;
        assign num[8] = x_in == 4'd8;
        assign num[9] = x_in == 4'd9;
        assign num[10] = x_in == 4'd10;
        assign num[11] = x_in == 4'd11;
        assign num[12] = x_in == 4'd12;
        assign num[13] = x_in == 4'd13;
        assign num[14] = x_in == 4'd14;
        assign num[15] = x_in == 4'd15;

        /* you could also do this with generation, like this:
         *
         * genvar i;
         * generate
         * for (i=0; i<16; i=i+1)begin
         *     assign num[i] = (x_in == i);
         * end
         * endgenerate
         */

        /* assign the seven output segments, sa through sg, using a "sum of products"
         * approach and the diagram above.
         */

       assign sa = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] ||num[14] ||num[15];
        assign sb = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
        assign sc = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
        assign sd = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
        assign se = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
        assign sf = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
        assign sg = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] ||num[15];
endmodule


`default_nettype wire

