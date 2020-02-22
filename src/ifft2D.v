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


module ifft2D #(
    parameter DATALEN = 16,
    parameter FFTCHNL = 8
)(
    input clk,
    input rstn,
    
    input invalid,
    input [2*DATALEN-1 : 0] indata[0 : FFTCHNL-1],
    
    output reg outvalid,
    output [2*DATALEN-1 : 0] outdata[0 : FFTCHNL-1][0 : 2-1]
);
    localparam CMPLXLEN = 2 * DATALEN;
    
    /*-------- 1D FFT along row --------*/
    wire [CMPLXLEN-1 : 0] _rowout_[0:FFTCHNL-1];
    wire _rownext_;
    idft_8data_top ifft_row(
        .clk(clk),
        .reset(~rstn),
        
        .next(invalid),
        .X0(indata[0][DATALEN-1 : 0]), 
        .X1(indata[0][2*DATALEN-1 : DATALEN]),
        .X2(indata[1][DATALEN-1 : 0]),
        .X3(indata[1][2*DATALEN-1 : DATALEN]),
        .X4(indata[2][DATALEN-1 : 0]),
        .X5(indata[2][2*DATALEN-1 : DATALEN]),
        .X6(indata[3][DATALEN-1 : 0]),
        .X7(indata[3][2*DATALEN-1 : DATALEN]),
        .X8(indata[4][DATALEN-1 : 0]),
        .X9(indata[4][2*DATALEN-1 : DATALEN]),
        .X10(indata[5][DATALEN-1 : 0]),
        .X11(indata[5][2*DATALEN-1 : DATALEN]),
        .X12(indata[6][DATALEN-1 : 0]),
        .X13(indata[6][2*DATALEN-1 : DATALEN]),
        .X14(indata[7][DATALEN-1 : 0]),
        .X15(indata[7][2*DATALEN-1 : DATALEN]),
        
        .next_out(_rownext_),
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
    
    /*-------- register all outputs --------*/
    reg [4-1 : 0] _wrcnt_, _rdcnt_;
    reg _colnext_, _rowvalid_;
    integer i;
    //>>>Critical
    // "64" is a specific value for 8x8 kernels, 
    // need change if kern size changes
    reg [CMPLXLEN-1 : 0] _colin_[0 : 64-1];
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _wrcnt_   <= 4'd0;
            _rdcnt_   <= 4'd0;
            _colnext_ <= 1'b0;
            _rowvalid_ <= 1'b0;
            for (i = 0; i < FFTCHNL; i=i+1) begin
                _colin_[i]    <= 'bx;  
                _colin_[i+8]  <= 'bx;
                _colin_[i+16] <= 'bx;
                _colin_[i+24] <= 'bx;
                _colin_[i+32] <= 'bx;
                _colin_[i+40] <= 'bx;
                _colin_[i+48] <= 'bx;
                _colin_[i+56] <= 'bx;
            end
        end
        else begin
            _rowvalid_ <= _rownext_; // data is valid in the next cycle
            //-> First receive data from row FFT
            if(_rowvalid_) begin
                for (i = 0; i < FFTCHNL; i=i+1) begin
                     _colin_[i]    <= _rowout_[i];
                     _colin_[i+8]  <= _colin_[i];
                     _colin_[i+16] <= _colin_[i+8];
                     _colin_[i+24] <= _colin_[i+16];
                     _colin_[i+32] <= _colin_[i+24];
                     _colin_[i+40] <= _colin_[i+32];
                     _colin_[i+48] <= _colin_[i+40];
                     _colin_[i+56] <=  _colin_[i+48];
                end
 
                _wrcnt_ <= _wrcnt_ + 1'b1;
            end

            //-> Output when all data is ready
            if(_wrcnt_ == 4'd7) begin
                _colnext_ <= 1'b1;
                _rdcnt_   <= 4'd0;
            end
            else begin
                _colnext_ <= 1'b0;
                if(_colnext_)
                    _rdcnt_ <= _rdcnt_ + 1;
                if(_rdcnt_ != 4'd0) begin
                    _rdcnt_ <= _rdcnt_ + 1;
                    for (i = 0; i < FFTCHNL; i=i+1) begin
                        _colin_[i]    <= {CMPLXLEN{1'b0}};
                        _colin_[i+8]  <= {CMPLXLEN{1'b0}};;
                        _colin_[i+16] <= _colin_[i];
                        _colin_[i+24] <= _colin_[i+8];
                        _colin_[i+32] <= _colin_[i+16];
                        _colin_[i+40] <= _colin_[i+24];
                        _colin_[i+48] <= _colin_[i+32];
                        _colin_[i+56] <=  _colin_[i+40];
                    end 
                end
            end
        end
    end
    
    /*-------- 1D FFT along col --------*/
    wire [FFTCHNL-1 : 0] _outnext_;
    genvar _colfft_;
    generate
    for (_colfft_ = 0; _colfft_ < FFTCHNL; _colfft_= _colfft_ + 1) begin
        idft_2data_top ifft_col(
            .clk(clk),
            .reset(~rstn),
            
            .next(_colnext_),
            .X0(_colin_[_colfft_+56][DATALEN-1 : 0]),
            .X1(_colin_[_colfft_+56][2*DATALEN-1 : DATALEN]),
            .X2(_colin_[_colfft_+48][DATALEN-1 : 0]),
            .X3(_colin_[_colfft_+48][2*DATALEN-1 : DATALEN]),
            
            .next_out(_outnext_[_colfft_]),
            .Y0(outdata[_colfft_][0][DATALEN-1 : 0]),
            .Y1(outdata[_colfft_][0][CMPLXLEN-1 : DATALEN]),
            .Y2(outdata[_colfft_][1][DATALEN-1 : 0]),
            .Y3(outdata[_colfft_][1][CMPLXLEN-1 : DATALEN])
        );
    end
    endgenerate
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            outvalid <= 1'b0;
        end
        else begin
            outvalid <= _outnext_[0];
        end
    end
   
endmodule
