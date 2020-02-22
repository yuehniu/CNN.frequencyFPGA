`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/29/2019 08:16:11 PM
// Design Name: 
// Module Name: reg_write
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


module reg_write #(
	parameter PARAKRN = 64,
	parameter PARATIL = 9,
	parameter DATALEN = 16,
	parameter INDXLEN = 6
)(
	input clk,
	input rstn,

	input [2*DATALEN-1 : 0] indata[0 : PARATIL-1][0 : PARAKRN-1],
	input [INDXLEN-1 : 0] inindex[0 : PARAKRN-1],
	input invalid[0 : PARAKRN-1],

	output reg [2*DATALEN-1 : 0] regdata[0 : PARATIL-1][0 : PARAKRN-1],
	output reg [INDXLEN-1 : 0] regindex[0 : PARAKRN-1],
	output reg regvalid[0 : PARAKRN-1]
);

	always @(posedge clk) begin
		regdata <= indata;
		regindex <= inindex;
		regvalid <= invalid;
	end
endmodule
