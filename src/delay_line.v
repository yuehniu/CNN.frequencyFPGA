`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/28/2019 03:31:34 PM
// Design Name: 
// Module Name: delay_line
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


module delay_line #(
    parameter PARAKRN = 64,
    parameter DATALEN = 6,
    parameter DELYNUM = 6
)(
    input clk,
    input rstn,
    
    input valid,
    input [DATALEN-1 : 0] indata [0 : PARAKRN-1],
    
    output [DATALEN-1 : 0] outdata_after_n_minus_1 [0 : PARAKRN-1],
    output [DATALEN-1 : 0] outdata_after_n [0 : PARAKRN-1]
);
    (* ram_style = "distributed" *) reg [DATALEN-1 : 0] delay_reg[0 : DELYNUM-1][0 : PARAKRN-1];
    
    integer i;
    always @(posedge clk) begin
        if (valid) begin
            delay_reg[0] <= indata;
            for (i = 1; i < DELYNUM; i++) begin
                delay_reg[i] <= delay_reg[i-1];
            end
        end
    end
    assign outdata_after_n = delay_reg[DELYNUM-1];
    assign outdata_after_n_minus_1 = delay_reg[DELYNUM-2];
endmodule
