`default_nettype none
`timescale 1ns/1ps

module filtered_frame_buffer #(
    parameter FILTERED_WIDTH = 131 // 128+3(padding for the 4 x 4 upsampling kernel size)
) (
    input wire clk_in,
    input wire rst_in,
    // buffer filtered pixel
    input wire frame_rst_in,
    input wire [15:0] filtered_in,
    input wire valid_write_in,
    // retrieve filtered pixel
    input wire valid_read_in,
    input wire [10:0] read_hor_addr_in,
    input wire [9:0] read_ver_addr_in,
    output logic [15:0] pixel_read_out,
    output logic valid_read_out
);
    logic [$clog2(FILTERED_WIDTH)-1:0] write_ver_addr;
    logic [$clog2(FILTERED_WIDTH)-1:0] write_hor_addr;
    logic [$clog2(FILTERED_WIDTH * 4)-1:0] write_addr, read_addr;
    logic write_enable;

    assign write_addr = {write_ver_addr[1:0], write_hor_addr};
    assign read_addr = {read_ver_addr_in[1:0], 
                        read_hor_addr_in[$clog2(FILTERED_WIDTH)-1:0]};

    pipeline #(
        .WIDTH(1),
        .STAGES(2)
    ) pipeline_filtered_frame_buffer (
        .clk_in(clk_in),
        .data_in(valid_read_in),
        .data_out(valid_read_out)
    );

    // Step 1: Write filtered pixels to BRAM
    always_ff @(posedge clk_in) begin
        if (rst_in || frame_rst_in) begin
            write_ver_addr  <= 0;
            write_hor_addr  <= 0;
        end else begin
            // write_hor_addr increments only when write is enabled
            write_hor_addr <= (valid_write_in)? write_hor_addr+1: write_hor_addr;

            // write_ver_add increments at the end of writing each line
            if (write_hor_addr == FILTERED_WIDTH) begin
                // increment within the cycle [0, FILTERED_WIDTH -1]
                write_ver_addr <= write_ver_addr + 1;
                write_hor_addr <= 0;
            end
        end
    end    

    // ========== BRAM Config ========== //
    // BRAM Port A: Write filtered pixels
    //      Port B: Read 4 x 4 pixel values to be ready for upsampling

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), // Color {5'b, 6'b, 5'b} is 16 bits wide
        .RAM_DEPTH(FILTERED_WIDTH * 4)) // Size of pixel row * 4 (for 4 x 4 patch scanning)
        single_row_buffer (
        .addra(write_addr),  // Write address logic    
        .clka(clk_in),
        .wea(valid_write_in),
        .dina(filtered_in),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(rst_in),
        .douta(),       // never read from this side
        .addrb(read_addr),
        .dinb(24'b0),        // write data unnecessary
        .clkb(clk_in),
        .web(1'b0),     // disable writes
        .enb(valid_read_in),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(pixel_read_out)
    );
endmodule

`default_nettype wire