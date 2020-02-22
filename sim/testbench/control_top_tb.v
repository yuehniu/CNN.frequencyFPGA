`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/07/2019 03:22:03 PM
// Design Name: 
// Module Name: control_top_tb
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


module control_top_tb;
	localparam ADDRLEN = 32;

	reg clk, rstn;

	/*-------- interface --------*/
	reg start;
	reg [10-1 : 0] N;
	reg [10-1 : 0] M;
	reg [12-1 : 0] P;
	reg [10-1 : 0] Ns;
	reg [10-1 : 0] Ms;
	reg [10-1 : 0] Ps;
	reg inlast;
	reg [ADDRLEN-1 : 0] addrin;
	wire procin, innoneed;
	reg krnllast;
	reg [ADDRLEN-1 : 0] addrkrnl;
	wire prockrnl, krnlnoneed;
	reg indxlast;
	reg [ADDRLEN-1 : 0] addrindx;
	wire procindx, indxnoneed;
	wire [ADDRLEN-1 : 0] rdaddr;
	wire [16-1 : 0] transferlen;
	wire [10-1 : 0] offsetaddrkrn;
	reg ifftdone;
	wire ifftstart;
	reg readynext;
	wire layrdone;

	/*-------- clock and reset --------*/
	initial begin	
		#0  rstn = 1'b1;
		#5  rstn = 1'b0;
		#30 rstn = 1'b1;		
	end
	initial begin
		#0  clk  = 1'b0;

		forever #10 clk = ~clk;
	end

	/*-------- streaming parameter --------*/
	initial begin
		N = 10'd512;
		M = 10'd512;
		P = 12'd1152;
		Ns = 256;
		Ms = 512;
		Ps = 288;
	end

	/*-------- start address --------*/
	initial begin
		addrin = 32'h0_0_0_0_0_0_0_0;
		addrkrnl = 32'h0_0_0_0_f_0_0;
		addrindx = 32'h0_f_0_0_0_0_0;
	end

	/*-------- start --------*/
	initial begin
		#200
		@(posedge clk); 
		start = 1'b1;
		@(posedge clk);
		start = 1'b0;
	end

	/*-------- input signal --------*/
	initial begin
		#0 inlast = 0;
		forever begin
			inlast = 0;
			wait(procin);
			#200
			@(posedge clk);
			inlast = 1;
			@(posedge clk);
			inlast = 0;
		end
	end

	/*-------- kernel signal --------*/
	initial begin
		#0 krnllast = 0;
		forever begin
			krnllast = 0;
			wait(prockrnl);
			#200 
			@(posedge clk);
			krnllast = 1;
			@(posedge clk);
			krnllast = 0;
		end
	end

	/*-------- index signal --------*/
	initial begin
		#0 indxlast = 0;
		forever begin
			indxlast = 0;
			wait(procindx);
			#200
			@(posedge clk); 
			indxlast = 1;
			@(posedge clk);
			indxlast = 0;
		end
	end

	/*-------- conv --------*/
	initial begin
		#0 readynext = 0;
		forever begin
			wait(DUT.__state__ == 4'b0100);
			#200
			@(posedge clk); 
			readynext = 1;
			@(posedge clk);
			readynext = 0;
		end
	end

	/*-------- ifft --------*/
	initial begin
		ifftdone = 0;
		forever begin
			wait(ifftstart);
			#200
			@(posedge clk);
			ifftdone = 1;
			@(posedge clk);
			ifftdone = 0;
		end
	end

	/*-------- finish --------*/
	initial begin
		wait(layrdone);
		@(posedge clk);
		$finish;
	end

	/*-------- call module --------*/
	control_top DUT(
		.clk(clk), .rstn(rstn),

		.start(start),

		.N(N), .M(M), .P(P), .Ns(Ns), .Ps(Ps),

		.inlast(inlast), .addrin(addrin), .procin(procin), .innoneed(innoneed),

		.krnllast(krnllast), .addrkrnl(addrkrnl), .prockrnl(prockrnl), .krnlnoneed(krnlnoneed),

		.indxlast(indxlast), .addrindx(addrindx), .procindx(procindx), .indxnoneed(indxnoneed),

		.rdaddr(rdaddr), .transferlen(transferlen), .offsetaddrkrn(offsetaddrkrn),

		.ifftdone(ifftdone), .ifftstart(ifftstart),

		.readynext(readynext), .layrdone(layrdone)
	);

	/*-------- monitor process --------*/
	initial begin
		forever begin
			wait(ifftdone == 1);
			$display("Finish %d input tiles, %d kernels", DUT._Pdone_, DUT._Ndone_);
			wait(ifftdone == 0);
		end
	end
endmodule
