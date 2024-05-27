`timescale 1ns / 1ps
`default_nettype none

module blob_detection (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [6:0] y_in, //change to 7 bits, had these flipped, check for errors
                         input wire [5:0]  x_in, //change to 6 bits   
                         input wire blob_trigger_in,                  
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic next_pixel_out,
                         output logic valid_blob_out [5:1],
                         output logic [6:0] y_out [5:1],
                         output logic [5:0] x_out [5:1],
                         output logic valid_out,
                         output logic [15:0] debug);
  assign debug = {pixel_total[1][15:0]};//, pixel_total[2][3:0], pixel_total[3][3:0], state}; //x_sum[1][9:0] pixel_total[4][2:0], pixel_total[5][2:0]
  //your design here!
  localparam STEADY = 0;
  localparam COUNTING = 3;
  localparam DIVIDING = 1;
  localparam START = 0;
  localparam WAITING = 1;
  

  localparam LABELS = 10;
  
  logic [2:0] state;
  logic minor_state;
  logic [18:0] x_sum [5:1]; //2^12 pixels x 2 ^ 7 = 19 bits for max sum
  logic [18:0] y_sum [5:1];
  logic [19:0] pixel_total [5:1];

  logic [6:0] y_quotient [5:1];
  logic [5:0] x_quotient [5:1];

  logic x_valid_in [5:1], y_valid_in [5:1], x_valid_out [5:1], y_valid_out [5:1];
  logic xcom_ready [5:1], ycom_ready [5:1];

  //bram variables
  logic [11:0] addra_valid [4:1];
  logic [11:0] addrb_valid [4:1];
  
  logic [11:0] addra_label [4:1];
  logic [11:0] addrb_label [4:1];
  
  logic [11:0] addra_blob [5:1];
  logic [11:0] addrb_blob [5:1];

  logic [13:0] output_valid [4:1];
 
  logic [3:0] output_label [4:1];
  
  logic [11:0] output_blob [5:1];

  logic [13:0] input_valid [4:1];
 
  logic [3:0] input_label [4:1];

  logic [11:0] input_blob [5:1];

  //logic [11:0] address_buffer [3:0]; //to keep track of the address in question

  logic [3:0] selected_label; //label to use for blob
  
  //uncomment if need to store x_in and y_in locally (more safe)
  // logic [6:0] current_x;
  // logic [5:0] current_y; //want it for 2 cycles to add it up to running sum

  
//need 7 bits to express x, and 6 bits to express y. Might cause error if we enlarge the video so keep an eye on that..
// does genvar have to be outside?
  genvar i;
  generate 
    for (i=1; i<5; i++) begin
      xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(1), //each entry in this memory is 14 bits = 7 (x) + 6 (y) + 1 (valid)
        .RAM_DEPTH(64*48)) //downsample 320*240 by 5x5 or 76800/25 = 3072 entries for full frame
        valid_bram (
        .addra(addra_valid[i]), //pixels are stored using this math
        .clka(clk_in),
        .wea(1'b1),          //port a always writes new valid pixels
        .dina(input_valid[i]),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(addrb_valid[i]),//to read
        .dinb(14'b0),
        .clkb(clk_in),
        .web(1'b0),         //port b always reads the valid pixels
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(output_valid[i])
      );
      xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(4), //at most we will have 10 labels
        .RAM_DEPTH(64*48)) //downsample 320*240 by 5x5 or 76800/25 = 3072 entries for full frame
        label_bram (
        .addra(addra_label[i]), //pixels are stored using this math
        .clka(clk_in),
        .wea(1'b1),
        .dina(input_label[i]),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(), //never read from this side
        .addrb(addrb_label[i]),//to read existing labels
        .dinb(16'b0),
        .clkb(clk_in),
        .web(1'b0),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(output_label[i])
      );
    end

    for(i = 1; i < 6; i++) begin
    
      divider xdivider(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(x_sum[i]),
        .divisor_in(pixel_total[i]),
        .data_valid_in(x_valid_in[i]),
        .quotient_out(x_quotient[i]),
        .data_valid_out(x_valid_out[i])
      );

      divider ydivider(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(y_sum[i]),
        .divisor_in(pixel_total[i]),
        .data_valid_in(y_valid_in[i]),
        .quotient_out(y_quotient[i]),
        .data_valid_out(y_valid_out[i])
      );
    end
  endgenerate

  localparam COUNTING_READY = 0;
  localparam COUNTING_TRANSITION = 1;
  localparam COUNTING_INPROGRESS = 2;
  logic [1:0] counting_state;
  logic inbounds [4:1];
  logic [2:0] next_label_available;
  logic [2:0] linked_to [5:1]; //maps a label[i] to another label
  logic is_linked_to [5:1]; //the linkee
  logic filtered_output_valid [4:1];
  logic [3:0] filtered_output_label [4:1];
  always_comb begin
    for (int i = 1; i < 5; i++) begin
      filtered_output_valid[i] = output_valid[i] && inbounds[i];
      filtered_output_label[i] = inbounds[i] ? output_label[i] : 0 ;
    end
  end

  always_ff @(posedge clk_in ) begin
    if (rst_in) begin
      valid_out <= 0;
      
      state <= COUNTING;
      minor_state <= 0;
      for (int i = 1; i < 6; i++) begin
        x_out[i] <= 0;
        y_out[i] <= 0;
        x_sum[i] <= 0;
        y_sum[i] <= 0;
        pixel_total[i] <= 0;
        x_valid_in[i] <= 0;
        y_valid_in[i] <= 0;
        xcom_ready[i] <= 0;
        ycom_ready[i] <= 0;
        linked_to[i] <= 0;
        is_linked_to[i] <= 0;
      end

      counting_state <= COUNTING_READY;
      next_label_available <= 1;
      //ready to receive next pixel
      next_pixel_out <= 0;

    end else begin
      case (state)
        STEADY: begin
          //if we are not supposed to be in blob state, patiently wait
          if (blob_trigger_in) begin
            state <= COUNTING;
            next_pixel_out <= 1; //we are ready to receive
          end
        end
        COUNTING: begin
          //trigger final calculation at the end of the frame(for now with tabulate_in)
          if (tabulate_in) begin
            //ignore the last pixel, not relevant enough
            state <= DIVIDING;
          end else begin
            case(counting_state)
              COUNTING_READY: begin
                
                // add valid pixel to VALID brams , 1 if valid, 0 if not valid, always
                for(int i = 1; i < 5; i++) begin
                  addra_valid[i] <= 48 * y_in + x_in;
                  input_valid[i] <= valid_in ? 1'b1 : 1'b0; // {1'b1, x_in, y_in} : 14'b0;
                end
                 
                if (!valid_in) begin
                  //set invalid pixel's label to 0;
                  for(int i = 1; i < 5; i++) begin
                    addra_label[i] <= 48 * y_in + x_in;
                    input_label[i] <= 3'b0;
                  end
                  next_pixel_out <= 1;  //we are ready for the next pixel
                end else begin

                  //start the 4 read requests
                  //check valid neighbors top 3 and left
                  //edge pixels will be out of bounds which will return random value, make note of it and multiplex with 0 
                  //top_left_neighbor
                  addrb_valid[1] <= 48 * (y_in-1) + (x_in - 1);
                  inbounds[1] <= (y_in-1) >= 0 && (x_in - 1) >= 0 ? 1'b1 : 1'b0;
                  //top_middle_neighbor 
                  addrb_valid[2] <= 48 * (y_in-1) + (x_in );
                  inbounds[2] <= (y_in-1) >= 0 && (x_in) >= 0 ? 1'b1 : 1'b0;
                  //top_right_neighbor 
                  addrb_valid[3] <= 48 * (y_in-1) + (x_in + 1);
                  inbounds[3] <= (y_in-1) >= 0 && (x_in + 1) >= 0 ? 1'b1 : 1'b0;
                  //left_neighbor 
                  addrb_valid[4] <= 48 * (y_in) + (x_in - 1);
                  inbounds[4] <= (y_in) >= 0 && (x_in - 1) >= 0 ? 1'b1 : 1'b0;

                  //also ask for those neighbor's labels
                  addrb_label[1] <= 48 * (y_in-1) + (x_in - 1);
                  addrb_label[2] <= 48 * (y_in-1) + (x_in );
                  addrb_label[3] <= 48 * (y_in-1) + (x_in + 1);
                  addrb_label[4] <= 48 * (y_in) + (x_in - 1);

                  //and switch to next counting state
                  counting_state <= COUNTING_TRANSITION;

                  next_pixel_out <= 0; //not ready for next pixel
                end
              end

              COUNTING_TRANSITION: begin
                //wasting first cycle, send to default which will send it to INPROGRESS
                counting_state <= COUNTING_INPROGRESS;
              end
              //take inbound into account, TODO!
              COUNTING_INPROGRESS: begin

                //we now filter the valid output based on bounds

                //gotta wait 2 cycles to finish fetching Valid and Label reads (or waste a cycle with intermediate state)
                if(filtered_output_valid[1] && filtered_output_valid[3] && !filtered_output_valid[2] && (filtered_output_label[1] != filtered_output_label[3])) begin
                  //we have 2 different labels and we must connect them
                  //new approach, both labels will be linked so just arbitraily add pixel to the first blob
                  for(int i = 1; i < 5; i++) begin
                    addra_label[i] <= 48 * y_in + x_in; // maybe save current x and y in new variables
                    input_label[i] <= filtered_output_label[1];
                  end
                  x_sum[filtered_output_label[1]] <= x_in + x_sum[filtered_output_label[1]]; 
                  y_sum[filtered_output_label[1]] <= y_in + y_sum[filtered_output_label[1]];
                  pixel_total[filtered_output_label[1]] <= 1 + pixel_total[filtered_output_label[1]];
                  //we must link the 2 labels now
                  linked_to[filtered_output_label[1]] <= filtered_output_label[3];
                  is_linked_to[filtered_output_label[3]] <= 1;

                end else if(filtered_output_valid[4] && filtered_output_valid[3] && !filtered_output_valid[2] && (filtered_output_label[4] != filtered_output_label[3])) begin
                  //we have 2 different labels and we must connect them
                  for(int i = 1; i < 5; i++) begin
                    addra_label[i] <= 48 * y_in + x_in; // maybe save current x and y in new variables
                    input_label[i] <= filtered_output_label[4];
                  end
                  x_sum[filtered_output_label[4]] <= x_in + x_sum[filtered_output_label[4]]; 
                  y_sum[filtered_output_label[4]] <= y_in + y_sum[filtered_output_label[4]];
                  pixel_total[filtered_output_label[4]] <= 1 + pixel_total[filtered_output_label[4]];
                  //we must link the 2 labels now
                  linked_to[filtered_output_label[4]] <= filtered_output_label[3];
                  is_linked_to[filtered_output_label[3]] <= 1;

                end else if (!(filtered_output_valid[4] || filtered_output_valid[3] || filtered_output_valid[1] || filtered_output_valid[2])) begin
                  //there are no valid neighbors, so start new label
                  for(int i = 1; i < 5; i++) begin
                    addra_label[i] <= 48 * y_in + x_in; // maybe save current x and y in new variables
                    input_label[i] <= next_label_available;
                  end
                  // sum the x and y and pixel_total (is this fine Or use case statement?)
                  x_sum[next_label_available] <= x_in; 
                  y_sum[next_label_available] <= y_in;
                  pixel_total[next_label_available] <= 1;
                  // cut it if labels are no longer available
                  if (next_label_available == LABELS) begin
                    state <= DIVIDING;
                  end
                  next_label_available <= next_label_available + 1; //monitor this one, might need 10 labels
                  
                end else begin
                  // we only have 1 label, so grab any nonzero label
                  
                    //inherit the first nonzero label we encounter. I no nonzero labels, label as 0 (impossible situation)
                    
                    //output label must also be filtered!
                    if (filtered_output_label[1] != 0 ) begin
                      for(int i = 1; i < 5; i++) begin
                        addra_label[i] <= 48 * y_in + x_in; 
                        input_label[i] <= filtered_output_label[1];
                      end
                      x_sum[filtered_output_label[1]] <= x_in + x_sum[filtered_output_label[1]]; 
                      y_sum[filtered_output_label[1]] <= y_in + y_sum[filtered_output_label[1]];
                      pixel_total[filtered_output_label[1]] <= 1 + pixel_total[filtered_output_label[1]];

                    end else if (filtered_output_label[2] != 0 ) begin
                      for(int i = 1; i < 5; i++) begin
                        addra_label[i] <= 48 * y_in + x_in; 
                        input_label[i] <= filtered_output_label[2];
                      end
                      x_sum[filtered_output_label[2]] <= x_in + x_sum[filtered_output_label[2]]; 
                      y_sum[filtered_output_label[2]] <= y_in + y_sum[filtered_output_label[2]];
                      pixel_total[filtered_output_label[2]] <= 1 + pixel_total[filtered_output_label[2]];

                    end else if (filtered_output_label[3] != 0 ) begin
                      for(int i = 1; i < 5; i++) begin
                        addra_label[i] <= 48 * y_in + x_in; 
                        input_label[i] <= filtered_output_label[3];
                      end
                      x_sum[filtered_output_label[3]] <= x_in + x_sum[filtered_output_label[3]]; 
                      y_sum[filtered_output_label[3]] <= y_in + y_sum[filtered_output_label[3]];
                      pixel_total[filtered_output_label[3]] <= 1 + pixel_total[filtered_output_label[3]];

                    end else begin
                      for(int i = 1; i < 5; i++) begin
                        addra_label[i] <= 48 * y_in + x_in; 
                        input_label[i] <= filtered_output_label[4];
                      end
                      x_sum[filtered_output_label[4]] <= x_in + x_sum[filtered_output_label[4]]; 
                      y_sum[filtered_output_label[4]] <= y_in + y_sum[filtered_output_label[4]];
                      pixel_total[filtered_output_label[4]] <= 1 + pixel_total[filtered_output_label[4]];
                    end      
                end
                //now we are ready for a new pixel
                counting_state <= COUNTING_READY;
                next_pixel_out <= 1; 

              end
              default: begin
                //second cycle delay, ready for read outputs
                //counting_state <= COUNTING_INPROGRESS;
              end
            endcase
          end
        end

        DIVIDING: begin
          case(minor_state) 
            START: begin
              //only divide blobs with size > 0
              for (int i = 1; i < 6; i++ ) begin
                //add logic to skip over labels that were linked to
                if (is_linked_to[i]) begin
                  //we must skip this division
                  valid_blob_out[i] <= 1'b0;
                  //ready for output
                  xcom_ready[i] <= 1'b1;
                  ycom_ready[i] <= 1'b1;

                  //food for thought: x and y should be 0 but not explicitly filled, will they cause bad behavior in top level? when crosshairing
                end else begin
                  if (pixel_total[i] > 0) begin
                    //check if label is linked to another label
                    if (linked_to[i] == 0) begin
                      x_valid_in[i] <= 1'b1;
                      y_valid_in[i] <= 1'b1;
                      valid_blob_out[i] <= 1'b1;
                    end else begin
                      //try adding first linked label only for now (that label could be linked to another label)
                      //might be source of weird behavior
                      x_valid_in[i] <= 1'b1;
                      y_valid_in[i] <= 1'b1;
                      valid_blob_out[i] <= 1'b1;
                      x_sum[i] <= x_sum[i] + x_sum[linked_to[i]];
                      y_sum[i] <= y_sum[i] + y_sum[linked_to[i]];
                      pixel_total[i] <= pixel_total[i] + pixel_total[linked_to[i]];
                    end
                  end else begin
                    //say that the result is not valid so 0 valid blob
                  
                    valid_blob_out[i] <= 1'b0;
                    //ready for output
                    xcom_ready[i] <= 1'b1;
                    ycom_ready[i] <= 1'b1;
                  end    
                end
                
              end         
              minor_state <= WAITING;
            end
            WAITING: begin
              for (int i = 1; i < 6; i++) begin
                x_valid_in[i] <= 0;  //no more valid divisions
                y_valid_in[i] <= 0;
                if(x_valid_out[i]) begin
                  //could put directly on output
                  x_out[i] <= x_quotient[i];
                  xcom_ready[i] <= 1;
                end
                if (y_valid_out[i]) begin
                  y_out[i] <= y_quotient[i];
                  ycom_ready[i] <= 1;
                end
              end
              if (xcom_ready[1] && ycom_ready[1] && 
                xcom_ready[2] && ycom_ready[2] && 
                xcom_ready[3] && ycom_ready[3] && 
                xcom_ready[4] && ycom_ready[4] && 
                xcom_ready[5] && ycom_ready[5]) begin
                  valid_out <= 1;
                  //exit DIVIDING state
                  state <= 2;
              end
      
            end
          endcase
        end
        default: begin
          //reset values maybe at the trigger in waiting so we can see the numbers for longer
          valid_out <= 0;
          for(int i = 1; i < 6; i++) begin
            x_out[i] <= 0;
            y_out[i] <= 0;
            x_sum[i] <= 0;
            y_sum[i] <= 0;
            pixel_total[i] <= 0;
            x_valid_in[i] <= 0;
            y_valid_in[i] <= 0;
            xcom_ready[i] <= 0;
            ycom_ready[i] <= 0;
            linked_to[i] <= 0;
            is_linked_to[i] <= 0;
          end
          
          state <= STEADY;
          minor_state <= START;
          next_label_available <= 1; 
           

        end
      endcase
      
    end
  end


endmodule


`default_nettype wire
