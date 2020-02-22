`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/01/2019 11:29:22 AM
// Design Name: 
// Module Name: control_conv_tb
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


module control_conv_tb();

	reg clk, rstn;

	/*-------- load data control signal --------*/
	reg procin, invalid, inlast;
	wire inready;

	reg prockrnl, krnlvalid, krnlast;
	wire krnlready;

	reg procindx, indxvalid, indxlast;
	wire indxready;

	wire readynext;

	/*-------- FFT state --------*/
	reg fftvalid;

	/*-------- replica state --------*/
	reg replicaready;

	/*-------- conv control --------*/
	reg convdone;
	wire convstart;

	/*-------- IFF control --------*/
	reg ifftdone;
	wire ifftstart;



	/*-------- generate clock --------*/
	initial begin	
		#0  rstn = 1'b1;
		#5  rstn = 1'b0;
		#30 rstn = 1'b1;		
	end
	initial begin
		#0  clk  = 1'b0;

		forever #10 clk = ~clk;
	end

	/*-------- load data control --------*/
	reg [5-1 : 0] _cnt_inpt_;
	initial begin
		#0  _cnt_inpt_ = 5'd0;
		#20 procin     = 1'b1;

		wait (inlast == 1'b1);
		@(posedge clk);
		procin = 1'b0;
	end
	always @(posedge clk) begin
		invalid <= 1'b0;
		inlast  <= 1'b0;
		wait (inready == 1'b1);
		invalid <= 1'b1;

		if (_cnt_inpt_==5'd8) begin
			inlast <= 1'b1;
		end
		else begin
			inlast     <= 1'b0;
			_cnt_inpt_ <= _cnt_inpt_ + 1;
		end
	end

	reg [10-1 : 0] _cnt_krnl_;
	initial begin
		#0 _cnt_krnl_ = 10'd0;

		wait (inlast == 1'b1);
		@(posedge clk);
		@(posedge clk);

		#20 prockrnl = 1'b1;

		wait (krnlast == 1'b1) 
		@(posedge clk);
		prockrnl = 1'b0;
	end
	always @(posedge clk) begin
		krnlvalid <= 1'b0;
		krnlast   <= 1'b0;
		wait(krnlready == 1'b1);
		krnlvalid <= 1'b1;

		if(_cnt_krnl_ == 10'd512) begin
			krnlast <= 1'b1;
		end
		else begin
			krnlast    <= 1'b0;
			_cnt_krnl_ <= _cnt_krnl_ + 1;
		end
	end

	reg [10-1 : 0] _cnt_indx_;
	initial begin
		#0 _cnt_indx_ = 10'd0;

		wait(krnlast == 1'b1);
		@(posedge clk);
		@(posedge clk);

		#20 procindx = 1'b1;

		wait(indxlast == 1'b1);
		@(posedge clk);
		procindx = 1'b0;
	end
	always @(posedge clk) begin
		indxvalid <= 1'b0;
		indxlast  <= 1'b0;
		wait(indxready == 1'b1);
		indxvalid <= 1'b1;

		if (_cnt_indx_ == 10'd256) begin
			indxlast <= 1'b1;
		end
		else begin
			indxlast   <= 1'b0;
			_cnt_indx_ <= _cnt_indx_ + 1;
		end
	end

	/*-------- FFT control --------*/
	integer i;
	initial begin
		#0 fftvalid  = 1'b0;

		wait (invalid == 1'b1);
		for (i = 0; i < 64; i++)
			@(posedge clk);

		for (i = 0; i < 9; i++) begin
			@(posedge clk);
			fftvalid = 1'b1;
		end
		fftvalid = 1'b0;
	end

	/*-------- replica state --------*/
	initial begin
		#0 replicaready = 1'b0;

		wait(fftvalid == 1'b1);
		wait(fftvalid == 1'b0);
		replicaready = 1'b1;
	end

	/*-------- conv control --------*/
	initial begin
		convdone = 1'b0;

		wait(DUT._rd_inpt_done_ && DUT._rd_indx_done_ && DUT._rd_krnl_done_ &&
			DUT._proc_fft_done_ && DUT.replicaready);
		for (i = 0; i < 64; i++) begin
			@(posedge clk);
		end
		convdone = 1'b1;
	end

	/*-------- IFF control --------*/
	initial begin
		ifftdone = 1'b0;

		wait(convdone == 1'b1);
		for (i = 0; i < 64; i++) begin
			@(posedge clk);
		end
		ifftdone = 1'b1;
	end

	/*-------- Add model --------*/
	control_conv DUT(
		.clk(clk), .rstn(rstn),

		.procin(procin), .invalid(invalid), .inlast(inlast), .inready(inready),

		.prockrnl(prockrnl), .krnlvalid(krnlvalid), .krnlast(krnlast), .krnlready(krnlready),

		.procindx(procindx), .indxvalid(indxvalid), .indxlast(indxlast), .indxready(indxready),

		.readynext(readynext), .fftvalid(fftvalid), .replicaready(replicaready),

		.convdone(convdone), .convstart(convstart),

		.ifftdone(ifftdone), .ifftstart(ifftstart)
	);

	/*-------- end simulation --------*/
	initial begin
		wait(readynext);

		@(posedge clk) $finish;
	end
endmodule
