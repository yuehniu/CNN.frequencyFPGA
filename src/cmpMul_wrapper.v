`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2019 09:36:51 AM
// Design Name: 
// Module Name: cmpMul_wrapper
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


module cmpMul_wrapper #(
	parameter DATALEN = 16
)(
	input clk,
	input rstn,

	input s_axis_a_tvalid,
	input [2*DATALEN-1 : 0] s_axis_a_tdata,
	input s_axis_b_tvalid,
	input [2*DATALEN-1 : 0] s_axis_b_tdata,

	output m_axis_dout_tvalid,
	output [2*DATALEN-1 : 0] m_axis_dout_tdata
);

	wire _outvalid_;
	wire [2*DATALEN-1 : 0] _outdata_;
	reg _outvalid_reg_;
	reg [2*DATALEN-1 : 0] _outdata_reg_;
	cmpMul cmpMul_U(
        .aclk(clk),
                
        .s_axis_a_tvalid(s_axis_a_tvalid), 
        .s_axis_a_tdata(s_axis_a_tdata), 
        .s_axis_b_tvalid(s_axis_b_tvalid), 
        .s_axis_b_tdata(s_axis_b_tdata),
                
        .m_axis_dout_tvalid(_outvalid_), 
        .m_axis_dout_tdata(_outdata_)
    );

	assign m_axis_dout_tvalid = _outvalid_reg_;
	assign m_axis_dout_tdata  = _outdata_reg_;

	always @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			_outvalid_reg_ <= 1'b0;
			_outdata_reg_  <= 'bx;
		end
		else begin
			_outvalid_reg_ <= _outvalid_;
			_outdata_reg_  <= _outdata_;
		end
	end
endmodule
