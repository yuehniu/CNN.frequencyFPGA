`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/27/2019 10:52:02 AM
// Design Name: 
// Module Name: control_pe_tb
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


module control_pe_tb();
    localparam INDXLEN = 6;
    localparam IDLE = 3'b000;
    localparam READINIT = 3'b001; // start read index to input first
    localparam READDATA = 3'b010; // read input and kernels
    localparam OPMUL = 3'b011; // do multiplication
    localparam READPSUM = 3'b100; // read psum
    localparam OPADD = 3'b101; // do accumulation
    localparam WRITE = 3'b110; // write data into psum
    
    reg clk, rstn;
    reg start, mulvalid;
    wire [INDXLEN-1 : 0] raddr_inbuf;
    wire [INDXLEN-1 : 0] raddr_index;
    wire inready, krnready, rdfifo, outready;
    
    initial begin
        #0 clk <= 1'b0;
        #0 rstn <= 1'b1;
        #0 start <= 1'b0;
        #5 rstn <= 1'b0;
        #10 rstn <= 1'b1;
        
        #20 start <= 1'b1;
        forever #10 clk <= ~clk;
    end
    
    reg [4-1 : 0] _delay_cnt_;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _delay_cnt_ <= 4'd0;
        end
        else begin
            _delay_cnt_ <= _delay_cnt_ + 1'b1;
            
            if (_delay_cnt_ == 4'd8) begin
                mulvalid <= 1'b1;
            end
        end
    end
    
    control_pe DUT(
        .clk(clk), .rstn(rstn), 
        .start(start), .raddr_inbuf(raddr_inbuf), .raddr_index(raddr_index), .inready(inready), .krnready(krnready), 
        .mulvalid(mulvalid), .rdfifo(rdfifo), .outready(outready));
        
    initial begin
    wait(outready == 1'b1);
    wait(DUT._state_ == IDLE)
        @(posedge clk);
        @(posedge clk);
        $finish;
    end
endmodule
