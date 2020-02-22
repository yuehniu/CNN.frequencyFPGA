`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2019 11:26:48 AM
// Design Name: 
// Module Name: control_top
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
// This is the top controller to control the whole conv process,
// and implement flexible dataflow in the paper
//////////////////////////////////////////////////////////////////////////////////


module control_top #(
	parameter PARAKRN = 64,
	parameter PARATIL = 9,
	parameter DATALEN = 16,
	parameter INDXLEN = 6,
	parameter ADDRLEN = 32
)(
	input clk,
	input rstn,

	/*-------- start FPGA kernel --------*/
	input start,

	/*-------- layer parameters --------*/
	//>>>Critical
	// support at most 1024 kernels, 1024 channels,
	// 4096 input tiles
	input [10-1 : 0] N, // #kernels
	input [10-1 : 0] M, // #channels
	input [12-1 : 0] P, // #tiles

	/*-------- streaming parameters --------*/
	//>>>Info
	// "Ns" and "Ps" are aligned with representations
	// in the papers
	input [10-1 : 0] Ns,
	input [10-1 : 0] Ps,

	/*-------- load data control --------*/
	input inlast,
	input [ADDRLEN-1 : 0] addrin,
	output reg procin,
	output reg innoneed,
	input krnllast,
	input [ADDRLEN-1 : 0] addrkrnl,
	output reg prockrnl,
	output reg krnlnoneed,
	input indxlast,
	input [ADDRLEN-1 : 0] addrindx,
	output reg procindx,
	output reg indxnoneed,
	output reg [ADDRLEN-1 : 0] rdaddr,
	output reg [16-1 : 0] transferlen,
	output reg [10-1 : 0] offsetaddrkrn, // krn address offset

	/*-------- IFFT control --------*/
	input ifftdone,
	output reg ifftstart,

	/*-------- conv control --------*/
	input readynext,
	output reg [12-1 : 0] offsetaddrpsum,

	/*-------- done status --------*/
	output reg layrdone
);

	localparam IDLE = 4'b0000;
	localparam READKRNL = 4'b0001;
	localparam READINDX = 4'b0010;
	localparam READINPT = 4'b0011;
	localparam READDONE = 4'b0100;
	localparam DONECONV = 4'b0101;
	localparam PROCIFFT = 4'b0110;
	localparam WRITOUPT = 4'b0111;
	localparam DONELYER = 4'b1000;

	reg [4-1 : 0] __state__;

	reg [10-1 : 0] _Ndone_; // #kernels done
	reg [10-1 : 0] _Mdone_; // #ichnls done
	reg [12-1 : 0] _Pdone_; // #itiles done
	reg [10-1 : 0] _Nsdone_; // #kernels done in current streaming
	reg [10-1 : 0] _Msdone_; // #ichnls done in current streaming
	reg [12-1 : 0] _Psdone_; // #itiles done in current streaming
	reg [ADDRLEN-1 : 0] _nextrd_inpt_; // next input read addr
	reg [ADDRLEN-1 : 0] _nextrd_indx_; // next index read addr
	reg [ADDRLEN-1 : 0] _nextrd_krnl_; // next kernl read addr
	reg [ADDRLEN-1 : 0] _snaprd_inpt_; // snapshot input read addr
	reg [ADDRLEN-1 : 0] _snaprd_indx_; // snapshot index read addr
	reg [ADDRLEN-1 : 0] _snaprd_krnl_; // snapshot kernl read addr

	always_ff @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			__state__ <= IDLE;

			procin         <= 1'b0;
			prockrnl       <= 1'b0;
			procindx       <= 1'b0;
			ifftstart      <= 1'b0;
			layrdone       <= 1'b0;
			krnlnoneed     <= 1'b0;
			innoneed       <= 1'b0;
			indxnoneed     <= 1'b0;
			rdaddr         <= 'bx;
			transferlen    <= 'bx;
			offsetaddrkrn  <= 'bx;
			offsetaddrpsum <= 'bx;
			_Ndone_        <= 'bx;
			_Mdone_        <= 'bx;
			_Pdone_        <= 'bx;
			_Nsdone_       <= 'bx;
			_Msdone_       <= 'bx;
			_Psdone_       <= 'bx;
			_nextrd_krnl_  <= 'bx;
			_nextrd_indx_  <= 'bx;
			_nextrd_inpt_  <= 'bx;
			_snaprd_krnl_  <= 'bx;
			_snaprd_indx_  <= 'bx;
			_snaprd_inpt_  <= 'bx;
		end
		else begin
			case(__state__)
			IDLE: begin
				if(start) begin
					__state__ <= READINPT;

					procin        <= 1'b1;
					rdaddr        <= addrin;
					transferlen   <= 16'd2304; // 9x8x8x(2x2) bytes of inputs

					//-> store start reading addr for kernels, indices, inputs
					_nextrd_inpt_ <= addrin;
					_nextrd_krnl_ <= addrkrnl;
					_nextrd_indx_ <= addrindx;
					_snaprd_inpt_ <= addrin;
					_snaprd_indx_ <= addrindx;
					_snaprd_krnl_ <= addrkrnl;
				end
				_Pdone_        <= 12'd0;
				_Ndone_        <= 10'd0;
				_Mdone_        <= 10'd0;
				_Psdone_       <= 12'd0;
				_Nsdone_       <= 10'd0;
				_Msdone_       <= 12'd0;
				layrdone       <= 1'b0;
				innoneed       <= 1'b0;
				krnlnoneed     <= 1'b0;
				indxnoneed     <= 1'b0;
				offsetaddrkrn  <= 10'd0;
				offsetaddrpsum <= 12'd0;
			end
			READKRNL: begin
				if(krnllast) begin
					__state__ <= READINDX;

					procindx    <= 1'b1;
					rdaddr      <= _nextrd_indx_;
					//>>>Critical
					// indx length actually cannot be decided
					transferlen <= 16'd512;

					//-> record this read
					_Nsdone_ <= _Nsdone_ + 64;
					prockrnl    <= 1'b0;
					_nextrd_krnl_ <= _nextrd_krnl_ + transferlen;
				end
			end
			READINDX: begin
				if(indxlast) begin
					__state__ <= READDONE;

					_nextrd_indx_ <= _nextrd_indx_ + transferlen; 
					procindx      <= 1'b0;
				end
			end
			READINPT: begin
				if(inlast) begin
					if(~krnlnoneed) begin
						__state__ <= READKRNL;

						prockrnl      <= 1'b1;
						rdaddr        <= _nextrd_krnl_;
						//>>>Critical
					    // indx length actually cannot be decided
					    transferlen <= 16'd4096;					
					end
					else begin
						__state__ <= READDONE;
					end
					procin        <= 1'b0;
					_Psdone_      <= _Psdone_ + 9;
					_nextrd_inpt_ <= _nextrd_inpt_ + transferlen;
				end
			end
			READDONE: begin
				/*-------- core streaming control --------*/
				if(readynext) begin
					if(_Nsdone_ == Ns) begin
						if(_Psdone_ == Ps) begin
							if(_Msdone_ == M) begin
								__state__ <= PROCIFFT;

								ifftstart <= 1'b1;

								//-> save how many kernel, input tiles finished
								_Ndone_   <= _Ndone_ + _Nsdone_;
								//_Mdone_   <= _Mdone_ + _Msdone_;
								if(_Ndone_ == 0)
									_Pdone_   <= _Pdone_ + _Psdone_;
								_Nsdone_  <= 10'd0;
								_Msdone_  <= 10'd0;
								_Psdone_  <= 12'd0;
								offsetaddrkrn  <= 10'd0;
								offsetaddrpsum <= 12'd0;						
							end
							//--> read another group of kernels and input tiles
							//--> from a new input channel
							else begin
								__state__ <= READINPT;

								rdaddr       <= _nextrd_inpt_;
								procin       <= 1'b1;
								transferlen  <= 16'd2304; // 9x8x8x(2x2) bytes of inputs

								//-> kernels, indces, inputs all need update
								_Nsdone_  <= 10'd0;
								_Msdone_  <= _Msdone_ +1;
								_Psdone_  <= 12'd0;
								krnlnoneed     <= 1'b0;
								indxnoneed     <= 1'b0;
								innoneed       <= 1'b0;
								offsetaddrkrn  <= 10'd0;
								offsetaddrpsum <= 12'd0;
							end
						end
						//--> read another group of input tiles
						//--> keep kernel unchanged on chip
						//--> within the same input channel
						else begin
							__state__ <= READINPT;

							procin       <= 1'b1;
							rdaddr       <= _nextrd_inpt_;
					    	transferlen  <= 16'd2304;

					    	//-> kernel is reused
					    	krnlnoneed    <= 1'b1;
							indxnoneed    <= 1'b1;
							//--> offset has be decided in scheduling algorithm
							offsetaddrkrn  <= offsetaddrkrn + 16;
							offsetaddrpsum <= offsetaddrpsum + 64;
						end
					end
					//--> read another group of kernels
					//--> keep input unchnaged
					//--> within the same input channel
					else begin
						__state__ <= READKRNL;

						rdaddr        <= _nextrd_krnl_;
						prockrnl      <= 1'b1;
						transferlen   <= 16'd4096;
						//--> offset has be decided in scheduling algorithm
						offsetaddrkrn  <= offsetaddrkrn + 16;
						offsetaddrpsum <= offsetaddrpsum + 64;

						//-> input is reused
						innoneed      <= 1'b1;
					end
				end
			end
			PROCIFFT: begin
				ifftstart <= 1'b0;
				if (ifftdone) begin
					if(_Ndone_ == N) begin
						if (_Pdone_ == P) begin
							__state__ <= DONELYER;

							layrdone <= 1'b1;
						end
						else begin
							__state__ <= READINPT;

							rdaddr        <= _nextrd_inpt_;
							procin        <= 1'b1;
							transferlen   <= 16'd2304; // 9x8x8x(2x2) bytes of inputs

							_Ndone_ <= 10'd0;
							//-> update snapshot
							_snaprd_inpt_ <= _nextrd_inpt_;
							//-> update start addr;
							_nextrd_krnl_ <= _snaprd_krnl_;
							_nextrd_indx_ <= _snaprd_indx_;
						end
					end
					else begin
						__state__ <= READINPT;

						_nextrd_inpt_ <= _snaprd_inpt_;
						rdaddr        <= _snaprd_inpt_;
						procin        <= 1'b1;
						transferlen   <= 16'd2304; // 9x8x8x(2x2) bytes of inputs
					end
				end
			end
			DONELYER: begin
				__state__ <= IDLE;

				_Pdone_   <= 12'd0;
				_Ndone_   <= 10'd0;
				_Mdone_   <= 10'd0;
				_Psdone_  <= 12'd0;
				_Nsdone_  <= 10'd0;
				_Msdone_  <= 12'd0;
				procin    <= 1'b0;
				prockrnl  <= 1'b0;
				procindx  <= 1'b0;
				ifftstart <= 1'b0;
				layrdone  <= 1'b0;
			end
			default: begin
				__state__ <= IDLE;

				_Pdone_   <= 12'd0;
				_Ndone_   <= 10'd0;
				_Mdone_   <= 10'd0;
				_Psdone_  <= 12'd0;
				_Nsdone_  <= 10'd0;
				_Msdone_  <= 12'd0;
				procin    <= 1'b0;
				prockrnl  <= 1'b0;
				procindx  <= 1'b0;
				ifftstart <= 1'b0;
				layrdone  <= 1'b0;
			end
			endcase
		end
	end
endmodule
