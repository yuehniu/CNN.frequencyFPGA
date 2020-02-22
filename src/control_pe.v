`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/24/2019 09:57:44 PM
// Design Name: 
// Module Name: control_pe
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


module control_pe #(
    parameter INDXLEN = 6,
    parameter PARAKRN = 64
)(
    input clk,
    input rstn,
    
    input start, // Start one cycle (PARATIL * PARAKRN) process
    
    output reg [INDXLEN-1 : 0] raddr_inbuf,
    output reg [INDXLEN-1 : 0] raddr_index,
    output reg inready, // input is ready
    output reg krnready, // kernel is ready
    
    input mulvalid, // value from multilier is valid
    input [12-1 : 0] offsetaddrpsumin,
    output reg [12-1 : 0] offsetaddrpsumout,
    output reg rdfifo, // read fifo (valid flag, kernel indices)
    output reg outready,
    output reg done
);
    // Define state
    localparam IDLE = 3'b000;
    localparam READINIT = 3'b001; // start read index to input first
    localparam READDATA = 3'b010; // read input and kernels
    localparam OPMUL = 3'b011; // do multiplication
    localparam READPSUM = 3'b100; // read psum
    localparam OPADD = 3'b101; // do accumulation
    localparam WRITE = 3'b110; // write data into psum
   
    reg [3-1 : 0] _state_;
    reg [INDXLEN-1 : 0] _wr_cnt_;
    reg [INDXLEN-1 : 0] _rd_cnt_;
    reg _inready_, _inready2_, _krnready_, _krnready2_;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _state_ <= IDLE;
            
            _wr_cnt_    <= 'bx;
            _rd_cnt_    <= 'bx;
            raddr_inbuf <= 'bx;
            raddr_index <= 'bx;
            _inready_   <= 1'bx;
            _krnready_  <= 1'bx;
            rdfifo      <= 1'b0;
            outready    <= 1'b0;
            done        <= 1'b0;
            offsetaddrpsumout <= 'bx;
        end
        else begin
            case(_state_)
                IDLE: begin
                    if (start) begin
                        _state_ <= READINIT;
                    end
                    
                    _wr_cnt_    <= {INDXLEN{1'b0}};
                    _rd_cnt_    <= {INDXLEN{1'b0}};
                    raddr_inbuf <= 'b0;
                    raddr_index <= 'b0;
                    _inready_   <= 1'b0;
                    _krnready_  <= 1'b0;
                    rdfifo      <= 1'b0;
                    outready    <= 1'b0;
                    done        <= 1'b0;
                end
                READINIT: begin
                    _state_ <= READDATA;
                    
                    raddr_index <= raddr_index + 1;
                end
                READDATA: begin
                    _state_ <= OPMUL;
                
                    raddr_index <= raddr_index + 1;
                    raddr_inbuf <= raddr_inbuf + 1;
                end
                OPMUL: begin
                    if (mulvalid) begin
                        _state_ <= OPADD;
                        
                        rdfifo <= 1'b1;
                    end
                    else begin
                        _state_ <= OPMUL;
                        
                        rdfifo <= 1'b0;
                    end
                    _inready_  <= 1'b1;
                    _krnready_ <= 1'b1;
                    _rd_cnt_   <= _rd_cnt_ + 1;
                    // Keep read inputs and kernels
                    raddr_index <= raddr_index + 1;
                    raddr_inbuf <= raddr_inbuf + 1;
                end
                /*
                READPSUM: begin
                    _state_ <= OPADD;
                    
                    _inready_ <= 1'b1;
                    krnready <= 1'b1;
                    _rd_cnt_ <= _rd_cnt_ + 1;
                    // Keep read inputs and kernels
                    raddr_index <= raddr_index + 1;
                    raddr_inbuf <= raddr_inbuf + 1;
                end
                */
                OPADD: begin
                    _state_ <= WRITE;
                    
                    _inready_  <= 1'b1;
                    _krnready_ <= 1'b1;
                    _rd_cnt_ <= _rd_cnt_ + 1;
                    // Keep read inputs and kernels
                    raddr_index <= raddr_index + 1;
                    raddr_inbuf <= raddr_inbuf + 1;
                    offsetaddrpsumout <= offsetaddrpsumin;
                end
                WRITE: begin
                    if (_wr_cnt_ == 15) begin
                        _state_ <= IDLE;

                        done <= 1'b1;
                    end
                    else begin
                        _state_ <= WRITE;
                        
                        _wr_cnt_ <= _wr_cnt_ + 1;
                    end
                    outready <= 1'b1;
                    if (raddr_index != 16) begin
                        raddr_index <= raddr_index + 1;
                    end
                    if (raddr_inbuf != 16) begin
                        raddr_inbuf <= raddr_inbuf + 1;
                    end
                    
                    if (_rd_cnt_ == 16) begin
                        _inready_  <= 1'b0;
                        _krnready_ <= 1'b0;
                    end
                    else begin
                        _inready_  <= 1'b1;
                        _krnready_ <= 1'b1;
                        _rd_cnt_   <= _rd_cnt_ + 1;
                    end
                end
                default: begin
                    _state_ <= IDLE;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            inready  <= 1'b0;
            krnready <= 1'b0;
        end
        else begin
            _inready2_  <= _inready_;
            _krnready2_ <= _krnready_;
            inready     <= _inready2_;
            krnready    <= _krnready2_;
        end
    end
endmodule
