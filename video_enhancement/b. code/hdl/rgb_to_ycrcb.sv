/////////////////////////////////////////////////////////////////////
////                                                             ////
////  RGB to YCrCb Color Space converter                         ////
////                                                             ////
////  Converts RGB values to YCrCB (YUV) values                  ////
////  Y  = 0.299R + 0.587G + 0.114B                              ////
////  Cr = 0.713(R - Y)                                          ////
////  Cb = 0.565(B - Y)                                          ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: rgb2ycrcb.v,v 1.1.1.1 2002-03-26 07:25:01 rherveille Exp $
//
//  $Date: 2002-03-26 07:25:01 $
//  $Revision: 1.1.1.1 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               2022 change for 6.205 @MIT jodalyst
//                  * updated to SV standards and class style


`timescale 1ns/1ps

module rgb_to_ycrcb(
	input wire clk_in,
  input wire [9:0] r_in,
  input wire [9:0] g_in,
  input wire [9:0] b_in,
  output logic [9:0] y_out,
  output logic [9:0] cr_out,
  output logic [9:0] cb_out);

	logic [21:0] y1, cr1, cb1;

	/* step 1: Calculate Y, Cr, Cb
	 *
	 * Use N.M format for multiplication:
	 * Y  = 0.299 * R.000 + 0.587 * G.000 + 0.114 * B.000
	 * Y  = 0x132 * R + 0x259 * G + 0x074 * B
	 *
	 * Cr = 0.713(R - Y)
	 * Cr = 0.500 * R.000 + -0.419 * G.000 - 0.0813 * B.000
	 * Cr = (R >> 1) - 0x1AD * G - 0x053 * B
	 *
	 * Cb = 0.565(B - Y)
	 * Cb = -0.169 * R.000 + -0.332 * G.000 + 0.500 * B.000
	 * Cb = (B >> 1) - 0x0AD * R - 0x153 * G
   */

	// calculate Y
	logic [19:0] yr, yg, yb;

  always_ff @(posedge clk_in) begin
			yr <= 10'h132 * r_in;
			yg <= 10'h259 * g_in;
			yb <= 10'h074 * b_in;
			y1 <= yr + yg + yb;
  end

	/* calculate Cr */
	logic [19:0] crr, crg, crb;
  always_ff @(posedge clk_in) begin
			crr <=  r_in << 9;
			crg <=  10'h1ad * g_in;
			crb <=  10'h053 * b_in;
			cr1 <=  crr - crg - crb;
  end

	/* calculate Cb */
	logic [19:0] cbr, cbg, cbb;
  always_ff @(posedge clk_in) begin
			cbr <=  10'h0ad * r_in;
			cbg <=  10'h153 * g_in;
			cbb <=  b_in << 9;
			cb1 <=  cbb - cbr - cbg;
  end

	/* Step 2: Check Boundaries */
  always_ff @(posedge clk_in) begin
			y_out <= (y1[19:10] & {10{!y1[21]}}) | {10{(!y1[21] && y1[20])}};
			cr_out <= (cr1[19:10] & {10{!cr1[21]}}) | {10{(!cr1[21] && cr1[20])}};
			cb_out <= (cb1[19:10] & {10{!cb1[21]}}) | {10{(!cb1[21] && cb1[20])}};
  end
endmodule
