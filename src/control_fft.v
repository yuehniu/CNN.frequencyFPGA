`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/08/2019 03:16:41 PM
// Design Name: 
// Module Name: control_fft
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


module control_fft #(
	parameter PARATIL = 9,
	parameter FFTCHNL = 8,
	parameter DATALEN = 16,
	parameter INDXLEN = 6
)(
	input clk,
	input rstn,

	/*-------- axi input --------*/
	input axi_invalid,
	input axi_inlast,
	input [64-1 : 0] axi_indata,

	/*-------- to fft2D --------*/
	output reg fftvalid,
	output reg [FFTCHNL*2*DATALEN-1 : 0] fftdata[0 : PARATIL-1]
);
	localparam CMPLXLEN = 64;

	localparam IDLE     = 3'b000;
	localparam PROCDATA = 3'b001;
	localparam PROCFFT  = 3'b010;
	reg [3-1 : 0] __state__;

	reg [CMPLXLEN-1 : 0] _outbuf_[0 : PARATIL-1][0 : 64-1];
	reg [INDXLEN-1 : 0] _indx_;
	reg [3-1 : 0] _til_;
	integer i,j;

	always @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			__state__ <= IDLE;

			fftvalid <= 1'b0;
			for(i = 0; i < PARATIL; i++) begin
				fftdata[i]  <= 'bx;
			end
			_indx_   <= 'bx;
			_til_    <= 'bx;
		end
		else begin
			case(__state__)
				IDLE: begin
					if(axi_invalid) begin
						__state__ <= PROCDATA;

						_outbuf_[_til_][0] = axi_indata[31 : 0];
						_outbuf_[_til_][1] = axi_indata[63 : 32];
					end
					_indx_   <= 'b0;
					_til_    <= 'b0;
				end
				PROCDATA: begin
					if(axi_inlast) begin
						__state__ <= PROCFFT;

						_til_  <= 0;
						_indx_ <= 0;
					end
					if(axi_invalid) begin
						if (_indx_ == 63) begin
							_til_  <= _til_ + 1;
							_indx_ <= 0;
						end

						_outbuf_[_til_][0] = axi_indata[63 : 32];
						_outbuf_[_til_][1] = axi_indata[31 : 0];
						for(i = 2; i < 64; i++) begin
							_outbuf_[_til_][i] <= _outbuf_[_til_][i-2];
						end
					end
				end
				PROCFFT: begin
					if(_indx_ == 8) begin
						__state__ <= IDLE;

						_indx_   <= 'b0;
						_til_    <= 'b0;
						fftvalid <= 1'b0;
					end
					else begin
						fftvalid <= 1'b1;

						for(i = 0; i < PARATIL; i++) begin
							fftdata[i] = {_outbuf_[i][56], _outbuf_[i][57],
										  _outbuf_[i][58], _outbuf_[i][59],
										  _outbuf_[i][60], _outbuf_[i][61],
										  _outbuf_[i][62], _outbuf_[i][63]};
							//-> shift
							_outbuf_[i][0] <= 0;
							_outbuf_[i][1] <= 0;
							_outbuf_[i][2] <= 0;
							_outbuf_[i][3] <= 0;
							_outbuf_[i][4] <= 0;
							_outbuf_[i][5] <= 0;
							_outbuf_[i][6] <= 0;
							_outbuf_[i][7] <= 0;
							for(j = 8; j < 64; j++) begin
								_outbuf_[i][j] <= _outbuf_[i][j-8];
							end
						end

					end
				end
				default: begin
					__state__ <= IDLE;

					_indx_   <= 'b0;
					_til_    <= 'b0;
					fftvalid <= 1'b0;
				end
			endcase
		end
	end

endmodule
