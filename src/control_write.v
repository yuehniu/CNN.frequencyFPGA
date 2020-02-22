`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/08/2019 11:03:05 AM
// Design Name: 
// Module Name: control_write
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

/*-------- control write --------*/
//--> read data from IFFT, write them out to AXI control
module control_write #(
	parameter FFTSIZE = 8,
	parameter FFTCHNL = 8,
	parameter DATALEN = 8,
	parameter PARATIL = 9,
	parameter INDXLEN = 6
)
(
	input clk,
	input rstn,

	/*-------- IFFT data --------*/
	input [PARATIL-1 : 0] ifftvalid,
	input [2*DATALEN-1 : 0] ifftdata[0 : PARATIL-1][0 : FFTCHNL-1][0 : 2-1],

	/*-------- AXI output --------*/
	output reg axi_outvalid,
	input axi_outready,
	output reg axi_outlast,
	output reg [64-1 : 0] axi_outdata
);

	localparam CMPLXLEN = 2 * DATALEN;

	localparam IDLE = 4'b0000;
	localparam PROCDATA = 4'b0001;
	localparam PROCWRIT = 4'b0010;
	localparam DONE = 4'b0011;

	reg [4-1 : 0] __state__;
	(* ram_style = "distributed" *) reg [CMPLXLEN-1 : 0] _in_delay_[0 : PARATIL-1][0 : 64-1];
	integer i,j;
	reg [INDXLEN-1 : 0] _cnt_;
	reg [4-1 : 0] _til_;
	always @(posedge clk or negedge rstn) begin
		if (~rstn) begin
			__state__ <= IDLE;

			axi_outvalid <= 1'b0;
			axi_outlast  <= 1'b0;
			axi_outdata  <= 'bx;

			_cnt_ <= 'b0;
			_til_ <= 'b0;
		end
		else begin
			case(__state__)
			IDLE: begin
				if (ifftvalid) begin
					__state__ <= PROCDATA;
	
					for(i = 0; i < PARATIL; i++) begin
						for(j = 0; j < FFTCHNL; j++) begin
							_in_delay_[i][j] <= ifftdata[i][j][0];
							_in_delay_[i][j+8] <= ifftdata[i][j][1];
						end
					end
					_cnt_ <= _cnt_ + 1;
				end
				_til_ <= 'b0;
			end
			PROCDATA: begin
				if(_cnt_ == 4) begin
					__state__ <= PROCWRIT;

					_cnt_ <= 4'd0;
				end
				else begin
					__state__ <= PROCDATA;

					for(i = 0; i < PARATIL; i++) begin
						for(j = 0; j < FFTCHNL; j++) begin
							_in_delay_[i][j] <= ifftdata[i][j][0];
							_in_delay_[i][j+8] <= ifftdata[i][j][1];

							_in_delay_[i][j+16] <= _in_delay_[i][j];
							_in_delay_[i][j+24] <= _in_delay_[i][j+8];

							_in_delay_[i][j+32] <= _in_delay_[i][j+16];
							_in_delay_[i][j+40] <= _in_delay_[i][j+24];

							_in_delay_[i][j+48] <= _in_delay_[i][j+32];
							_in_delay_[i][j+56] <= _in_delay_[i][j+40];
						end
					end
					_cnt_ <= _cnt_ + 1;
				end
			end
			PROCWRIT: begin
				if(_cnt_ == 32) begin
					if(_til_ == 9) begin
						__state__ <= IDLE;

						axi_outvalid <= 1'b0;
						axi_outlast  <= 1'b0;
					end
					else begin
						_til_ <= _til_ + 1;
						_cnt_ <= 0;
					end
				end
				else begin
					if(axi_outready) begin
						axi_outvalid <= 1'b1;
						if(_cnt_ == 31)
							axi_outlast <= 1'b1;
						axi_outdata <= {_in_delay_[_til_][62],_in_delay_[_til_][63]};
						_in_delay_[_til_][0] <= 'b0;
						_in_delay_[_til_][1] <= 'b0;
						for (j = 0; j < 62; j++) begin
							_in_delay_[_til_][j+2] <= _in_delay_[_til_][j];
						end
						_cnt_ <= _cnt_ + 1;
					end
				end
			end
			endcase
		end
	end
endmodule
