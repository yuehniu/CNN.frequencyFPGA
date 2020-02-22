`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/02/2019 07:23:17 PM
// Design Name: 
// Module Name: control_ifft
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module control_ifft #(
	parameter INDXLEN = 6,
	parameter DATALEN = 16,
	parameter PARATIL = 9,
	parameter PARAKRN = 64,
	parameter FFTCHNL = 8
)(
	input clk,
	input rstn,

	/*-------- control signal --------*/
	input ifftstart,

	/*-------- data signal --------*/
	output reg ifftrd,
	output reg [12-1 : 0] rdaddr,
	input  [2*DATALEN-1 : 0] rddata[0 : PARATIL-1][0 : PARAKRN-1],
	output reg ifftnext, // data is ready to pick up in next cycle
	output reg [2*DATALEN-1 : 0] ifftin[0 : PARATIL-1][0 : FFTCHNL-1],

	/*-------- ifft status --------*/
	output reg ifftdone
);
	localparam CMPLXLEN = 2 * DATALEN;

	localparam IDLE     = 4'b0000;
	localparam PROCDATA = 4'b0001;
	localparam PROCIFFT = 4'b0010;
	localparam DONE     = 4'b0011;
	reg [4-1 : 0] __state__;

	reg [8-1 : 0] _cnt_ochnl_;
	reg [4-1 : 0] _cnt_ifft_;
	// reg [INDXLEN-1 : 0] _bufaddr_;
	integer i, j, _til_, _c_;
	//>>>Critical
	// "64" is very specific to current 8x8 kernels
	reg [CMPLXLEN-1 : 0] _outbuf_[0 : PARATIL-1][0 : 64-1];
	always @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			__state__ <= IDLE;

			ifftrd      <= 1'b0;
			ifftnext    <= 1'b0;
			ifftdone    <= 1'b0;
			_cnt_ochnl_ <= 'bx;
			_cnt_ifft_  <= 'bx;
		end
		else begin
			case (__state__)
				IDLE: begin
					rdaddr      <= {12{1'b0}};
					ifftrd      <= 1'b0;
					ifftnext    <= 1'b0;
					ifftdone    <= 1'b0;
					_cnt_ochnl_ <= 8'd0;
					_cnt_ifft_  <= 4'd0;
					if (ifftstart) begin
						__state__ <= PROCDATA;

						rdaddr <= rdaddr + 1;
						ifftrd <= 1'b1;
					end
				end
				PROCDATA: begin
					if (rdaddr[5:0] == 63) begin
						__state__ <= PROCIFFT;

						ifftnext  <= 1'b1;
						ifftrd    <= 1'b0;
						//rdaddr    <= {INDXLEN{1'b0}};
					end

					rdaddr <= rdaddr + 1;

					for (_til_ = 0; _til_ < PARATIL; _til_++) begin
						_outbuf_[_til_][0] <= rddata[_til_][_cnt_ochnl_];
						for (i = 0; i < 63; i++) begin
							_outbuf_[_til_][i+1] <= _outbuf_[_til_][i];
						end
					end
				end
				PROCIFFT: begin
					if(_cnt_ifft_ == 4'd8) begin
						if(_cnt_ochnl_ == 8'd64) begin
							__state__ <= DONE;

							_cnt_ifft_  <= 4'd0;
							ifftrd      <= 1'b0;
							ifftdone    <= 1'b1;
						end
						else begin
							__state__ <= PROCDATA;

							_cnt_ifft_  <= 4'd0;
							_cnt_ochnl_ <= _cnt_ochnl_ + 1;
							rdaddr      <= rdaddr + 1;
							ifftrd      <= 1'b1;
						end
					end

					ifftnext   <= 1'b0;
					_cnt_ifft_ <= _cnt_ifft_ + 1;
					//-> generate ifft input at _outbuf_[63 : 56]
					for (_til_ = 0; _til_ < PARATIL; _til_++) begin
						for (_c_ = 0; _c_ < FFTCHNL; _c_++) begin
							ifftin[_til_][_c_] <= _outbuf_[_til_][63 - _c_];
						end
					end
					//-> shift _outbuf_
					for (_til_ = 0; _til_ < PARATIL; _til_++) begin
						for (j = 0; j < 8; j++) begin
							_outbuf_[_til_][i] <= {CMPLXLEN{1'b0}};
						end
						
						for (i = 8; i < 63; i++) begin
							_outbuf_[_til_][i+1] <= _outbuf_[_til_][i-8];
						end
					end
				end
				DONE: begin
					__state__ <= IDLE;

					ifftdone    <= 1'b0;
				end
				default: begin
					__state__ <= IDLE;
				end
			endcase
		end
	end
endmodule
