`timescale 1ns / 1ps
`default_nettype none

module com_tb;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic [10:0] x_in;
    logic [9:0] y_in;
    logic valid_in;
    logic tabulate_in;
    logic [10:0] x_out;
    logic [9:0] y_out;
    logic valid_out;

    center_of_mass uut(.clk_in(clk_in), .rst_in(rst_in),
                         .x_in(x_in),
                         .y_in(y_in),
                         .valid_in(valid_in),
                         .tabulate_in(tabulate_in),
                         .x_out(x_out),
                         .y_out(y_out),
                         .valid_out(valid_out));
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("com.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,com_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        x_in = 11'b0;
        y_in = 10'b0;
        valid_in = 0;
        tabulate_in = 0;
        #10  //wait a little bit of time at beginning
        rst_in = 1; //reset system
        #10; //hold high for a few clock cycles
        rst_in=0;
        #10;
        for (int i = 0; i<1000; i= i+1)begin
          x_in = i;
          y_in = i/2;
          valid_in = 1;
          #10;
        end
        valid_in = 0;
        #100;
        tabulate_in = 1;
        #10000;
        tabulate_in=0;
        #10;

        // test case 1: feed 700 valid pixels continuously
        for (int i = 0; i<700; i= i+1)begin
          x_in = i;
          y_in = i;
          valid_in = 1;
          #10;
        end
        valid_in = 0;
        #50;
        tabulate_in = 1;
        #10;
        tabulate_in = 0;
        #10000;

        // test case 2: one valid pixel
        x_in = 10;
        y_in = 5;
        valid_in = 1;
        #10;
        valid_in=0;
        #10;
        tabulate_in = 1;
        #10;
        tabulate_in = 0;
        #10000;

        // test case 3: 1024 x 768 valid pixels 
        for (int i=0; i< 1024; i++) begin
            for (int j=0; j<768; j++) begin
                x_in = i;
                y_in = j;
                valid_in = 1;
                #10;
            end
        end
        valid_in=0;
        #10;
        tabulate_in = 1;
        #10;
        tabulate_in = 0;
        #20000;

        // test case 4: tabulate_in = 1 with no valid pixels
        tabulate_in = 1;
        #10;
        tabulate_in = 0;
        #10000;

        $display("Finishing Sim"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire