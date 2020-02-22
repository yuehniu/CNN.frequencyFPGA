`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/29/2019 08:39:41 PM
// Design Name: 
// Module Name: control_conv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Version:
// V0.0
// >>>>Critical
// Double buffer is not implemented in currect version
// 
//////////////////////////////////////////////////////////////////////////////////

module control_conv(
	input clk,
	input rstn,

	/*-------- load data control --------*/
	input procin, // start read input data
	input invalid,
	input inlast,
	input innoneed, // no need to read new data
	output reg inready,

	input prockrnl, // start read kernel data
	input krnlvalid,
	input krnllast,
	input krnlnoneed, // no need to read kernels
	output reg krnlready,

	input procindx, // start read index data
	input indxvalid,
	input indxlast,
	input indxnoneed, // no need to read indices
	output reg indxready,

	output reg readynext, // ready for next group conv

	/*-------- FFT state --------*/
	input fftvalid,

	/*-------- replica state --------*/
	input replicaready,

	/*-------- conv control --------*/
	input convdone,
	output reg convstart,
	input offsetaddrpsumin,
	output reg [12-1 : 0] offsetaddrpsumout
);
	/*-------- State definition --------*/
	localparam IDLE     = 4'b0000;
	localparam PROCKRNL = 4'b0001;
	localparam PROCINDX = 4'b0010;
	localparam PROCINPT = 4'b0011;
	localparam PROCCONV = 4'b0100;
	localparam PROCIFFT = 4'b0101;
	localparam WAIT     = 4'b0111;

	reg [4-1 : 0] __state__;
	reg [4-1 : 0] _cnt_fft_;
	reg _rd_krnl_done_, _rd_indx_done_, _rd_inpt_done_;
	reg _proc_fft_done_;
	always @(posedge clk or negedge rstn) begin
		if (~rstn) begin
			inready    <= 1'b0;
			krnlready  <= 1'b0;
			indxready  <= 1'b0;
			convstart  <= 1'b0;
			readynext  <= 1'b0;
			offsetaddrpsumout <= 12'dx;
		end
		else begin
			case (__state__)
				IDLE: begin
					inready           <= 1'b0;
					krnlready         <= 1'b0;
					indxready         <= 1'b0;
					convstart         <= 1'b0;
					readynext         <= 1'b0;
					offsetaddrpsumout <= 12'dx;
					_rd_krnl_done_    <= 1'b0;
					_rd_indx_done_    <= 1'b0;
					_rd_inpt_done_    <= 1'b0;
					if (procin) begin
						__state__ <= PROCINPT;

						inready <= 1'b1;
					end
					else if(prockrnl) begin
						__state__ <= PROCKRNL;

						krnlready <= 1'b1;
					end
					else if (procindx) begin
						__state__ <= PROCINDX;

						indxready <= 1'b1;
					end
					else begin
						__state__ <= IDLE;
					end
				end
				PROCKRNL: begin
					if (krnllast) begin
						__state__ <= WAIT;

						krnlready      <= 1'b0;
						_rd_krnl_done_ <= 1'b1;
					end
				end
				PROCINDX: begin
					if (indxlast) begin
						__state__ <= WAIT;

						indxready      <= 1'b0;
						_rd_indx_done_ <= 1'b1;
					end
				end
				PROCINPT: begin
					if (inlast) begin
						__state__ <= WAIT;

						inready        <= 1'b0;
						_rd_inpt_done_ <= 1'b1;
					end
				end
				PROCCONV: begin
					if (convdone) begin
						__state__ <= IDLE;

						readynext <= 1'b1;
					end
					convstart <= 1'b0;	
				end
				WAIT: begin
					if ((_rd_inpt_done_ && _proc_fft_done_ && replicaready) || 
						innoneed && 
						(_rd_indx_done_ || indxnoneed) &&
						(_rd_krnl_done_ || krnlnoneed) ) begin
						__state__ <= PROCCONV;

						convstart <= 1'b1;
						offsetaddrpsumout <= offsetaddrpsumin;

						//-> clear all "done" signal
						_rd_inpt_done_ <= 1'b0;
						_rd_indx_done_ <= 1'b0;
						_rd_krnl_done_ <= 1'b0;
					end
					else begin
						if (procin) begin
							__state__ <= PROCINPT;
	
								inready <= 1'b1;
							end
							else if(prockrnl) begin
								__state__ <= PROCKRNL;
	
								krnlready <= 1'b1;
							end
							else if (procindx) begin
								__state__ <= PROCINDX;
	
								indxready <= 1'b1;
						end
					end
				end
				default: begin
					__state__ <= IDLE;	
				end
			endcase
		end
	end

	/*-------- monitor 2Dfft --------*/
	always @(posedge clk or negedge rstn) begin
		if (~rstn) begin
			_cnt_fft_       <= 4'd0;
			_proc_fft_done_ <= 1'b0;
		end
		else begin
			if (fftvalid) begin
				_cnt_fft_ <= _cnt_fft_ + 1;

				//>>>>Critical
				// "4'd7" really depends on 2dfft design,
				// in current design, 2dfft is finished
				// 7 clock cycles.
				if (_cnt_fft_ == 4'd7) begin
					_proc_fft_done_ <= 1'b1;
				end
			end

			if (convstart) begin
				_cnt_fft_       <= 4'd0;
				_proc_fft_done_ <= 1'b0;
			end
		end
	end
endmodule
