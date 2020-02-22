`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/19/2019 09:23:47 PM
// Design Name: 
// Module Name: fft2D
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


module fft2D #(
    parameter DATALEN = 16,
    parameter FFTCHNL = 8
)(
    input clk,
    input rstn,
    
    input invalid,
    input [FFTCHNL*2*DATALEN-1 : 0] indata,
    
    output outvalid,
    output [FFTCHNL*2*2*DATALEN-1 : 0] outdata
);
    localparam CMPLXLEN = 2 * DATALEN;
    
    //--> 1D FFT along row
    wire [CMPLXLEN-1 : 0] _rowout_[0:FFTCHNL-1];
    wire _rowvalid_;
    dft_8data_top fft_row(
        .clk(clk),
        .reset(~rstn),
        
        .next(invalid),
        .X0(indata[DATALEN-1 : 0]), 
        .X1(indata[2*DATALEN-1 : 1*DATALEN]),
        .X2(indata[3*DATALEN-1 : 2*DATALEN]),
        .X3(indata[4*DATALEN-1 : 3*DATALEN]),
        .X4(indata[5*DATALEN-1 : 4*DATALEN]),
        .X5(indata[6*DATALEN-1 : 5*DATALEN]),
        .X6(indata[7*DATALEN-1 : 6*DATALEN]),
        .X7(indata[8*DATALEN-1 : 7*DATALEN]),
        .X8(indata[9*DATALEN-1 : 8*DATALEN]),
        .X9(indata[10*DATALEN-1 : 9*DATALEN]),
        .X10(indata[11*DATALEN-1 : 10*DATALEN]),
        .X11(indata[12*DATALEN-1 : 11*DATALEN]),
        .X12(indata[13*DATALEN-1 : 12*DATALEN]),
        .X13(indata[14*DATALEN-1 : 13*DATALEN]),
        .X14(indata[15*DATALEN-1 : 14*DATALEN]),
        .X15(indata[16*DATALEN-1 : 15*DATALEN]),
        
        .next_out(_rowvalid_),
        .Y0(_rowout_[0][DATALEN-1 : 0]), 
        .Y1(_rowout_[0][2*DATALEN-1 : DATALEN]),
        .Y2(_rowout_[1][DATALEN-1 : 0]),
        .Y3(_rowout_[1][2*DATALEN-1 : DATALEN]),
        .Y4(_rowout_[2][DATALEN-1 : 0]),
        .Y5(_rowout_[2][2*DATALEN-1 : DATALEN]),
        .Y6(_rowout_[3][DATALEN-1 : 0]),
        .Y7(_rowout_[3][2*DATALEN-1 : DATALEN]),
        .Y8(_rowout_[4][DATALEN-1 : 0]),
        .Y9(_rowout_[4][2*DATALEN-1 : DATALEN]),
        .Y10(_rowout_[5][DATALEN-1 : 0]),
        .Y11(_rowout_[5][2*DATALEN-1 : DATALEN]),
        .Y12(_rowout_[6][DATALEN-1 : 0]),
        .Y13(_rowout_[6][2*DATALEN-1 : DATALEN]),
        .Y14(_rowout_[7][DATALEN-1 : 0]),
        .Y15(_rowout_[7][2*DATALEN-1 : DATALEN])
    );
    
    //--> Transposes
    reg [1-1 : 0] _cnt_;
    reg _colvalid_;
    integer i;
    reg [CMPLXLEN-1 : 0] _colin_[0:15];
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _cnt_      <= 1'b0;
            _colvalid_ <= 1'b0;
            for (i = 0; i < FFTCHNL; i=i+1) begin
                _colin_[i] <= 'bx;  
                _colin_[i+8] <= 'bx;
            end
        end
        else begin
            if(_rowvalid_) begin
                if(_cnt_ == 1'b0) begin
                    _colvalid_ <= 1'b0;
                    for (i = 0; i < FFTCHNL; i=i+1) begin
                        _colin_[i] <= _rowout_[i];
                    end
                end
                else begin
                    _colvalid_ <= 1'b1;
                    for (i = 0; i < FFTCHNL; i=i+1) begin
                        _colin_[i+8] <= _rowout_[i];
                    end
                end
                _cnt_ <= _cnt_ + 1'b1;
            end
            else begin
                _colvalid_ <= 1'b0;
            end
        end
    end
    
    //--> 1D FFT along column
    wire [FFTCHNL-1 : 0] _outvalid_;
    genvar _colfft_;
    generate
    for (_colfft_ = 0; _colfft_ < FFTCHNL; _colfft_= _colfft_ + 1) begin
        dft_2data_top fft_col(
            .clk(clk),
            .reset(~rstn),
            
            .next(_colvalid_),
            .X0(_colin_[_colfft_][DATALEN-1 : 0]),
            .X1(_colin_[_colfft_][2*DATALEN-1 : DATALEN]),
            .X2(_colin_[_colfft_+8][DATALEN-1 : 0]),
            .X3(_colin_[_colfft_+8][2*DATALEN-1 : DATALEN]),
            
            .next_out(_outvalid_[_colfft_]),
            .Y0(outdata[(_colfft_+1)*2*CMPLXLEN-CMPLXLEN-DATALEN-1 : _colfft_*2*CMPLXLEN]),
            .Y1(outdata[(_colfft_+1)*2*CMPLXLEN-CMPLXLEN-1 : (_colfft_+1)*2*CMPLXLEN-CMPLXLEN-DATALEN]),
            .Y2(outdata[(_colfft_+1)*2*CMPLXLEN-CMPLXLEN+DATALEN-1 : (_colfft_+1)*2*CMPLXLEN-CMPLXLEN]),
            .Y3(outdata[(_colfft_+1)*2*CMPLXLEN-1 : (_colfft_+1)*2*CMPLXLEN-CMPLXLEN+DATALEN])
        );
    end
    endgenerate
    assign outvalid = &_outvalid_;
   
endmodule
