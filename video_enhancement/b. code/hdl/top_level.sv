`timescale 1ns / 1ps
`default_nettype none

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw, //all 16 input slide switches
    input wire [3:0] btn, //all four momentary button switches
    output logic [2:0] rgb0, //rgb led
    output logic [2:0] rgb1, //rgb led
    output logic [15:0] led, //16 green output LEDs (located right above switches)
    output logic [2:0] hdmi_tx_p, //hdmi output signals (blue, green, red)
    output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives)
    output logic hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
    input wire [7:0] pmoda,
    input wire [2:0] pmodb,
    input wire [2:0] pmodb_in,
    output logic pmodbclk,
    output logic pmodblock
    );
    // size of upscaled frame to be displayed
    parameter FRAME_HEIGHT = 512;
    parameter FRAME_WIDTH  = 512;

    // have btnd control system reset
    logic sys_rst;
    assign sys_rst = btn[0];

    // shut up those rgb LEDs (active high):
    assign rgb1= 0;
    assign rgb0 = 0;

    // easy to debug (show active switch with LEDs)
    assign led = sw;

    // variable for seven-segment module
    logic [6:0] ss_c;

    // Clocking Variables:
    logic clk_pixel, clk_5x; //clock lines (pixel clock and 1/2 tmds clock)
    logic locked; //locked signal (we'll leave unused but still hook it up)

    //Signals related to driving the video pipeline
    logic [10:0] hcount, hcount_pipe; //horizontal count
    logic [9:0] vcount, vcount_pipe; //vertical count
    logic vert_sync, vert_sync_pipe; //vertical sync signal
    logic hor_sync, hor_sync_pipe; //horizontal sync signal
    logic active_draw, active_draw_pipe; //active draw signal
    logic new_frame, new_frame_pipe; //new frame (use this to trigger center of mass calculations)
    logic [5:0] frame_count, frame_count_pipe; //current frame

    //camera module: (see datasheet)
    logic cam_clk_buff, cam_clk_in; //returning camera clock
    logic vsync_buff, vsync_in; //vsync signals from camera
    logic href_buff, href_in; //href signals from camera
    logic [7:0] pixel_buff, pixel_in; //pixel lines from camera
    logic [15:0] cam_pixel; //16 bit 565 RGB image from camera
    logic valid_pixel; //indicates valid pixel from camera
    logic frame_done; //indicates completion of frame from camera

    //outputs of the recover module
    logic [15:0] pixel_data_rec; // pixel data from recovery module
    logic [10:0] hcount_rec; //hcount from recovery module
    logic [9:0] vcount_rec; //vcount from recovery module
    logic  data_valid_rec; //single-cycle (74.25 MHz) valid data from recovery module

    // ========= Registers for Image Filtering ========== //
    //outputs of the upscale signal generator
    logic [10:0] hcount_upscale;
    logic [9:0]  vcount_upscale;
    logic frame_rst;
    logic valid_upscale;

    //outputs of image filtering pixel shift
    logic [15:0] unfiltered_pixel_array [2:0][2:0];
    logic valid_unfiltered_pixel_array;

    //outputs of filtered pixel value
    logic [15:0] filtered_pixel;
    logic valid_filtered_pixel;

    // ========= Registers for Image Upscaling ========== //
    //values read from filtered frame buffer
    logic [15:0] read_filtered_pixel;
    logic valid_read_filtered_pixel;

    //outputs of image filtering pixel shift
    logic [15:0] filtered_pixel_array [3:0][3:0];
    logic valid_filtered_pixel_array;

    // ================================================== //

    //output of the shifted modules
    logic [10:0] hcount_shifted; //shifted hcount for looking up camera frame pixel
    logic [9:0] vcount_shifted; //shifted vcount for looking up camera frame pixel
    logic valid_addr_shifted; //whether or not two values above are valid (or out of frame)

    //values from the frame buffer:
    logic [15:0] frame_buff_raw; //output of frame buffer (direct)
    logic [15:0] frame_buff; //output of frame buffer OR black (based on pipeline valid)

    //outputs of the rotation module
    logic [16:0] img_addr_rot; //result of image transformation rotation
    logic valid_addr_rot; //forward propagated valid_addr_scaled
    logic valid_addr_rot_pipe; //pipelining variables in || with frame_buffer

    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;

    // Pixel shift & bicubic interpolation modules connection
    logic [15:0] pixel_array [3:0][3:0];
    logic valid_pixel_array;

    // Bicubic interpolation & upscaled frame buffer modules connection
    logic [7:0] red_array [3:0][3:0], green_array [3:0][3:0], blue_array [3:0][3:0];
    logic valid_upscaled_pixel_array;

    // Original pixel values to be displayed 
    logic valid_read_upscaled_pixel;
    logic [7:0] upscaled_red, upscaled_green, upscaled_blue;

    //final processed red, gren, blue for consumption in tmds module
    logic [7:0] red, green, blue;

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic tmds_signal [2:0]; //output of each TMDS serializer!

    //Clock domain crossing to synchronize the camera's clock
    //to be back on the 65MHz system clock, delayed by a clock cycle.
    always_ff @(posedge clk_pixel) begin
        cam_clk_buff <= pmodb[0]; //sync camera
        cam_clk_in <= cam_clk_buff;
        vsync_buff <= pmodb[1]; //sync vsync signal
        vsync_in <= vsync_buff;
        href_buff <= pmodb[2]; //sync href signal
        href_in <= href_buff;
        pixel_buff <= pmoda; //sync pixels
        pixel_in <= pixel_buff;
    end


    // Receive hand signal from the other FPGA
    // horizontal, vertical offset, and image filter selection
    logic [10:0] h_offset;
    logic [9:0]  v_offset;
    logic [2:0] filter_mode;

    // SPI related variables
    logic [3:0] spi_rx_data; //data generated by spi_rx module
    logic new_data; //indicator from spi_rx a new "word" has been received!
    logic data_clk; //incoming data clock signal for spi rx (after sync)
    logic data_line; //incoming data line for spi rx (after sync)
    logic select; //incoming select line for spi rx (after sync)

    synchronizer s1
        ( .clk_in(clk_pixel),
            .rst_in(sys_rst),
            .us_in(pmodb_in[0]),
            .s_out(data_line));

    synchronizer s2
        ( .clk_in(clk_pixel),
            .rst_in(sys_rst),
            .us_in(pmodb_in[1]),
            .s_out(data_clk));

    synchronizer s3
        ( .clk_in(clk_pixel),
            .rst_in(sys_rst),
            .us_in(pmodb_in[2]),
            .s_out(select));

    spi_rx #(.DATA_WIDTH(4))
        ( .clk_in(clk_pixel),
            .rst_in(sys_rst),
            .data_in(data_line),
            .sel_in(select),
            .data_clk_in(data_clk),
            .data_out(spi_rx_data),
            .new_data_out(new_data)
        );

    hand_signal_decoder hs_decoder_m (
        .clk_in(clk_pixel),
        .new_data_in(new_data),
        .data_in(spi_rx_data),
        .h_offset(h_offset),
        .v_offset(v_offset),
        .filter_mode(filter_mode)
    );

    // clock manager; creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS,respectively
    hdmi_clk_wiz_720p mhdmicw (
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz)
    );

    //from week 04! (make sure you include in your hdl) (same as before)
    video_sig_gen mvg(
        .clk_pixel_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_out(hcount),
        .vcount_out(vcount),
        .vs_out(vert_sync),
        .hs_out(hor_sync),
        .ad_out(active_draw),
        .nf_out(new_frame),
        .fc_out(frame_count)
    );
    //Controls and Processes Camera information
    camera camera_m(
        .clk_pixel_in(clk_pixel),
        .pmodbclk(pmodbclk), //data lines in from camera
        .pmodblock(pmodblock), //
        //returned information from camera (raw):
        .cam_clk_in(cam_clk_in),
        .vsync_in(vsync_in),
        .href_in(href_in),
        .pixel_in(pixel_in),
        //output framed info from camera for processing:
        .pixel_out(cam_pixel), //16 bit 565 RGB pixel
        .pixel_valid_out(valid_pixel), //pixel valid signal
        .frame_done_out(frame_done) //single-cycle indicator of finished frame
    );

    //camera and recover module are kept separate since some users may eventually
    //want to add pre-processing on signal prior to framing into hcount/vcount-based
    //values.

    //The recover module takes in information from the camera
    // and sends out:
    // * 5-6-5 pixels of camera information
    // * corresponding hcount and vcount for that pixel
    // * single-cycle valid indicator
    recover recover_m (
        .valid_pixel_in(valid_pixel),
        .pixel_in(cam_pixel),
        .frame_done_in(frame_done),
        .system_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .pixel_out(pixel_data_rec), //processed pixel data out
        .data_valid_out(data_valid_rec), //single-cycle valid indicator
        .hcount_out(hcount_rec), //corresponding hcount of camera pixel
        .vcount_out(vcount_rec) //corresponding vcount of camera pixel
    );

    //two-port BRAM used to hold image from camera.
    //because camera is producing video for 320 by 240 pixels at ~30 fps
    //but our display is running at 720p at 60 fps, there's no hope to have the
    //production and consumption of information be synchronized in this system
    //instead we use a frame buffer as a go-between. The camera places pixels in at
    //its own rate, and we pull them out for display at the 720p rate/requirement
    //this avoids the whole sync issue. It will however result in artifacts when you
    //introduce fast motion in front of the camera. These lines/tears in the image
    //are the result of unsynced frame-rewriting happening while displaying. It won't
    //matter for slow movement
    //also note the camera produces a 320*240 image, but we display it 240 by 320
    //(taken care of by the rotate module below).
    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), //each entry in this memory is 16 bits
        .RAM_DEPTH(320*240)) //there are 240*320 or 76800 entries for full frame
        frame_buffer (
        .addra(hcount_rec + 320*vcount_rec), //pixels are stored using this math
        .clka(clk_pixel),
        .wea(data_valid_rec),
        .dina(pixel_data_rec),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst),
        .douta(), //never read from this side
        .addrb(img_addr_rot),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(valid_addr_rot),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb(frame_buff_raw)
    );

    //start of the full video pipeline is here...
    //hcount, vcount, etc... are used for coming up with what to draw.

    // trigger the bicubic interpolation module and retrieve the correct pixels
    // of each 4 x 4 image pixels in order.
    upscale_sig_gen upscale_sig_gen_m (
        .clk_in(clk_pixel),
        .h_offset(h_offset),
        .v_offset(v_offset),
        .hcount_in(hcount),
        .vcount_in(vcount),
        // for filtering pixels
        .hcount_filter_out(hcount_shifted),
        .vcount_filter_out(vcount_shifted),
        .valid_filter_out(valid_addr_shifted),
        .frame_rst_out(frame_rst),
        // for upsampling pixels
        .hcount_upscale_out(hcount_upscale),
        .vcount_upscale_out(vcount_upscale),
        .valid_upscale_out(valid_upscale)
    );

    //Rotates and mirror-images Image to render correctly (pi/2 CCW rotate):
    // The output address should be fed right into the frame buffer for lookup
    rotate rotate_m (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_in(hcount_shifted),
        .vcount_in(vcount_shifted),
        .valid_addr_in(valid_addr_shifted),
        .pixel_addr_out(img_addr_rot),
        .valid_addr_out(valid_addr_rot)
        );

    // Pipeline the valid_addr_rot by 2 cycles since it takes 2 cycles to
    // read new value from the xilinx dual port BRAM
    pipeline #(
        .STAGES(2),
        .WIDTH(1)) 
    pipeline_valid_addr_rot (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(valid_addr_rot),
      .data_out(valid_addr_rot_pipe));
    // If invalid BRAM readings, set frame buffer reads to zero (just in case)
    assign frame_buff = (valid_addr_rot_pipe)? frame_buff_raw : 16'b0;

    // arrange sequential input of 16 x 16 pixels in to appropriate array,
    // and output valid signal every 4 cycles (only when 4 x 4 image patch is ready)
    pixel_shift #(
        .WIDTH(16),
        .HOR_SIZE(3),
        .VER_SIZE(3)
    ) filtering_pixel_shift (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .valid_in(valid_addr_rot_pipe),
        .pixel_in(frame_buff),
        .pixel_array_out(unfiltered_pixel_array),
        .valid_out(valid_unfiltered_pixel_array)
    );

    image_filter image_filter_m (
        .clk_in(clk_pixel),
        .valid_in(valid_unfiltered_pixel_array),
        .filter_mode_in(filter_mode),
        .color_channel_in(sw[1:0]),
        .unfiltered_in(unfiltered_pixel_array),
        .filtered_out(filtered_pixel),
        .valid_out(valid_filtered_pixel)
    );


    filtered_frame_buffer filtered_frame_buffer_m (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        // buffer filtered pixel
        .frame_rst_in(frame_rst),
        .filtered_in(filtered_pixel),
        .valid_write_in(valid_filtered_pixel),
        // retrieve filtered pixel
        .read_hor_addr_in(hcount_upscale),
        .read_ver_addr_in(vcount_upscale),
        .valid_read_in(valid_upscale),
        .pixel_read_out(read_filtered_pixel),
        .valid_read_out(valid_read_filtered_pixel)
    );

    pixel_shift upscaling_pixel_shift (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .valid_in(valid_read_filtered_pixel),
        .pixel_in(read_filtered_pixel),
        .pixel_array_out(filtered_pixel_array),
        .valid_out(valid_filtered_pixel_array)
    );

    // upscale the input 4 x 4 pixels to upscaled 4 x 4 pixel array
    bicubic_interpolation bicubic_interpolation_m (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .valid_in(valid_filtered_pixel_array),
        .pixel_array_in(filtered_pixel_array),
        .r_out(red_array),
        .g_out(green_array),
        .b_out(blue_array),
        .valid_out(valid_upscaled_pixel_array)
    );

    assign valid_read_upscaled_pixel = (hcount < FRAME_WIDTH) && (vcount < FRAME_HEIGHT);
    // two ports/multi-lined frame buffer for temporarily storing upscaled pixels
    // 4 BRAMs store 4 rows of pixels, which are rewritten before next line starts displaying
    upscaled_frame_buffer upscaled_frame_buffer_m (
        // port 1: buffer new pixels
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .r_in(red_array), .g_in(green_array), .b_in(blue_array),
        .valid_write_in(valid_upscaled_pixel_array),

        // port 2: read buffered pixels
        .valid_read_addr_in(valid_read_upscaled_pixel),
        .hcount_in(hcount),
        .vcount_in(vcount),
        .r_out(upscaled_red), .g_out(upscaled_green), .b_out(upscaled_blue)
    );

    // Upscaled frame buffer takes 2 cycles to read
    // 2-Stage Pipeline for HDMI control signals 
    pipeline #(
        .STAGES(2),
        .WIDTH(3)) 
    pipeline_hdmi_control_sig (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in({active_draw,
            vert_sync, 
            hor_sync}),
      .data_out({active_draw_pipe, 
            vert_sync_pipe, 
            hor_sync_pipe}));

    //three tmds_encoders (blue, green, red)
    tmds_encoder tmds_red(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(upscaled_red),
        .control_in(2'b0),
        .ve_in(active_draw_pipe),
        .tmds_out(tmds_10b[2]));

    tmds_encoder tmds_green(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(upscaled_green),
        .control_in(2'b0),
        .ve_in(active_draw_pipe),
        .tmds_out(tmds_10b[1]));

    tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(upscaled_blue),
        .control_in({vert_sync_pipe,hor_sync_pipe}),
        .ve_in(active_draw_pipe),
        .tmds_out(tmds_10b[0]));

    //four tmds_serializers (blue, green, red, and clock)
    tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2]));

    tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1]));

    tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0]));

    //output buffers generating differential signal:
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));


endmodule // top_level


`default_nettype wire
