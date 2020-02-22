`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2019 09:07:40 PM
// Design Name: 
// Module Name: buf_replica_tb
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


module buf_replica_tb();
    localparam DATALEN = 16;
    localparam FFTCHNL = 8;
    localparam REPLICA = 8;
    localparam INDXLEN = 6;

    reg clk, rstn;
    
    reg invalid;
    reg [2*DATALEN-1 : 0] indata[0 : 2*FFTCHNL-1];
    
    reg [INDXLEN-1 : 0] outaddr[0:REPLICA-1];
    wire [2*DATALEN-1 : 0] outdata[0:REPLICA-1];
    
    initial begin
        #0 clk <= 0;
        #0 rstn <= 1;
        #5 rstn <= 0;
        #10 rstn <= 1;
        forever #10 clk <= ~clk;
    end
    
    reg [6-1 : 0] count;
    integer i;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            count <= 2'd0;
            
            invalid <= 1'b0;
            for (i = 0; i < 2*FFTCHNL; i++) begin
                indata[i] = {(2*DATALEN){1'b0}};
            end
        end
        else begin
            if (count <= 6'd3) begin   
                count <= count + 1'b1;            
                invalid <= 1'b1;
                for (i = 0; i < 2*FFTCHNL; i++) begin
                    indata[i] <= indata[i]+1'b1;
                end
            end
            else if (count < {INDXLEN{1'b1}}) begin
                count <= count + 1'b1;
                invalid <= 1'b0;
            end
            else begin
                invalid <= 1'b0;
            end
        end
    end
    
    reg [INDXLEN-1 : 0] addr_count;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            addr_count <= {INDXLEN{1'b0}};
            for (i = 0; i < REPLICA; i++) begin
                outaddr[i] = {INDXLEN{1'b0}};
            end
        end
        else begin
            if (count == {INDXLEN{1'b1}}) begin
                addr_count <= addr_count + 1;
                for (i = 0; i < REPLICA; i++) begin
                    outaddr[i] <= outaddr[i] + 1'b1;
                end
            end
        end
    end
    always @(addr_count) begin
        if (addr_count == {INDXLEN{1'b1}})
            $finish;
    end
    
    buf_replica_wrapper DUT(
        .clk(clk),
        .rstn(rstn),
        
        .invalid(invalid), .indata(indata),
        
        .outaddr(outaddr), .outdata(outdata)
    );
endmodule
