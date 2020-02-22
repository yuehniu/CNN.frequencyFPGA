`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2019 07:42:01 PM
// Design Name: 
// Module Name: replica_route
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


module replica_route #(
    parameter DATALEN = 16,
    parameter REPLLEN = 4,
    parameter REPLICA = 8,
    parameter INDXLEN = 6
    
)(
    input clk,
    input rstn,

    input [REPLLEN-1 : 0] mux,
    input [2*DATALEN-1 : 0] indata[0 : REPLICA-1],
    input [INDXLEN-1 : 0] inindex[0: REPLICA-1],
    
    output [INDXLEN-1 : 0] outindex,
    output [2*DATALEN-1 : 0] outdata
);

    reg [INDXLEN-1 : 0] _outindex_dly_;
    reg [2*DATALEN-1 : 0] _outdata_dly_;

    always @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            _outindex_dly_ <= 'bx;
            _outdata_dly_  <= 'bx;
        end
        else begin
            _outindex_dly_ <= inindex[mux];
            _outdata_dly_  <= indata[mux];
        end
    end
    assign outindex = _outindex_dly_;
    assign outdata = _outdata_dly_;
endmodule
