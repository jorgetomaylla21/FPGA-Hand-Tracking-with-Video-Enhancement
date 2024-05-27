`timescale 1ns / 1ps
`default_nettype none

//Regulating the pixels going into blob_detection
//Must wait for new_pixel signal to give the next pixel
module signal_controller(
  input wire clk_in,
  input wire rst_in,
  input wire signal_in,
  input wire [10:0]vcount,
  input wire [9:0] hcount,
  output logic [5:0] x_out,
  output logic [6:0] y_out,
  output logic frame_end_out,
  output logic blob_trigger_out
);

//state logic
logic [1:0] state;
localparam WAITING = 0;
localparam BLOB_TRIGGER = 1;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      state <= WAITING;
      x_out <= 0;
      y_out <=0;
      frame_end_out <= 0;
    end else begin
        
      case(state) 
        WAITING: begin
            //trigger signal if vcount = 320 and hcount = 0;
            if (vcount == 320 && hcount == 0) begin
                state <= BLOB_TRIGGER;
                blob_trigger_out <= 1;
            end
        end
        BLOB_TRIGGER: begin
            blob_trigger_out <= 0;
            //when blob is ready to accept next pixel
            if (signal_in) begin
                //maybe off by 1 cycle
                if (x_out == 47 && y_out == 63) begin
                    //restart the frame read
                    x_out <= 0;
                    y_out <= 0;
                    //have to trigger the end of frame
                    frame_end_out <= 1;
                    state <= 2;
                end else begin
                    frame_end_out <= 0;
                    //feed next pixel to blob_detection
                    //increase the pixels for the next pixels
                    x_out <= (x_out + 1 == 48) ? 0 : x_out + 1 ;
                    if (x_out >= 47) begin
                        y_out <= y_out + 1;
                    end
                    
                end 
            end
        end
        default: begin
            //clean variables to start the next cycle
            state <= WAITING;
            x_out <= 0;
            y_out <=0;
            frame_end_out <= 0;
        end
      endcase
      
    end
  end
endmodule


`default_nettype wire
