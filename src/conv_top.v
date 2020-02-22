`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/19/2019 08:32:16 PM
// Design Name: 
// Module Name: conv_top
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


module conv_top #(
    parameter FFTSIZE = 8,
    parameter FFTCHNL = 8,
    parameter PARATIL = 9,  // #parallel tiles
    parameter PARAKRN = 64, // #parallel kernels
    parameter REPLICA = 8,  // #replicas 
    parameter REPLLEN = 4,
    parameter DATALEN = 16, // data length
    parameter ADDRLEN = 32,
    parameter INDXLEN = 6   // index length for sparse kernels
)(
    input clk,
    input rstn,
    
    input start,
    /*-------- layer definition --------*/
    input [10-1 : 0] N,
    input [10-1 : 0] M,
    input [12-1 : 0] P,

    /*-------- streaming parameter --------*/
    input [10-1 : 0] Ns,
    input [10-1 : 0] Ps,
    
    /*-------- load data --------*/
    input invalid,
    output inready,
    input inlast,
    input [ADDRLEN-1 : 0] addrin,
    input [64-1 : 0] indata,
    
    input krnlvalid,
    output krnlready,
    input krnllast,
    input [ADDRLEN-1 : 0] addrkrnl,
    input [64-1 : 0] krnldata, // AXI compatible interface
    
    input indxvalid,
    output indxready,
    input indxlast,
    input [ADDRLEN-1 : 0] addrindx,
    input [64-1 : 0] indxdata, // AXU compatible interface
    
    output axi_outvalid,
    input axi_outready,
    output axi_outlast,
    output [64-1 :0] axi_outdata, // AXI compatible interface

    /*-------- AXI control --------*/
    output [ADDRLEN-1 : 0] axirdaddr,
    output [16-1 : 0] axitransferlen,

    /*-------- status --------*/
    output layrdone
);

    localparam CMPLXLEN = 2 * DATALEN;
    /*-------- flow control --------*/
    wire _procin_, _prockrnl_, _procindx_, _readynext_;
    wire _innoneed_, _krnlnoneed_, _indxnoneed_;
    wire _ifftstart_, _ifftdone_;
    wire [12-1 : 0] _offsetaddrpsumin_;
    wire [12-1 : 0] _offsetaddrpsumout_;
    control_top control_top_U(
        .clk(clk), .rstn(rstn),

        .start(start),

        .N(N), .M(M), .P(P), .Ns(Ns), .Ps(Ps),

        .inlast(inlast), .addrin(addrin), .procin(_procin_), .innoneed(_innoneed_),

        .krnllast(krnllast), .addrkrnl(addrkrnl), .prockrnl(_prockrnl_), .krnlnoneed(_krnlnoneed_),

        .indxlast(indxlast), .addrindx(addrindx), .procindx(_procindx_), .indxnoneed(_indxnoneed_),

        .rdaddr(axirdaddr), .transferlen(axitransferlen),

        .offsetaddrkrn(), 

        .ifftdone(_ifftdone_), .ifftstart(_ifftstart_),

        .readynext(_readynext_), .offsetaddrpsum(_offsetaddrpsumin_), .layrdone(layrdone)
    );

    /*-------- conv control --------*/
    wire _convstart_;
    control_conv control_conv_U(
        .clk(clk), .rstn(rstn),

        .procin(_procin_), .invalid(invalid), .inlast(inlast), .innoneed(_innoneed_), .inready(inready),

        .prockrnl(_prockrnl_), .krnlvalid(krnlvalid), .krnllast(krnllast), .krnlnoneed(_krnlnoneed_), .krnlready(krnlready),

        .procindx(_procindx_), .indxvalid(indxvalid), .indxlast(indxlast), .indxnoneed(_indxnoneed_), .indxready(indxready),

        .readynext(_readynext_), .fftvalid(_fftout_valid_[0]),

        .replicaready(_replicaready_[0]),

        .convdone(_convdone_), .convstart(_convstart_), .offsetaddrpsumin(_offsetaddrpsumin_), .offsetaddrpsumout(_offsetaddrpsumout_)
    );
    
    /*-------- 2D FFT transform --------*/ 
    wire _fftin_valid_;
    wire [PARATIL-1 : 0] _fftkrnl_ready_;
    wire [PARATIL-1 : 0] _fftout_valid_;
    wire [FFTCHNL*2*DATALEN-1 : 0] _fftin_[0 : PARATIL-1];
    wire [PARATIL*FFTCHNL*2*CMPLXLEN-1 : 0] _fftout_;
    control_fft #(
        .PARATIL(PARATIL),
        .FFTCHNL(FFTCHNL),
        .DATALEN(DATALEN),
        .INDXLEN(INDXLEN)
    )control_fft_U(
        .clk(clk), .rstn(rstn),

        .axi_invalid(invalid), .axi_inlast(inlast), .axi_indata(indata),

        .fftvalid(_fftin_valid_), .fftdata(_fftin_)
    );
    genvar _til_;
    generate
    for (_til_ = 0; _til_ < PARATIL; _til_ = _til_+1) begin:FFT_TILES
        fft2D #(
            .DATALEN(DATALEN),
            .FFTCHNL(FFTCHNL)
        )(
            .clk(clk), .rstn(rstn),
            
            .indata(_fftin_[_til_]),
            .invalid(_fftin_valid_),
            
            .outdata(_fftout_[(_til_+1)*FFTCHNL*2*CMPLXLEN-1 : _til_*FFTCHNL*2*CMPLXLEN]),
            .outvalid(_fftout_valid_[_til_])
        );
    end
    endgenerate
    
    /*-------- Store spectral input tiles into replica buffer --------*/ 
    genvar _r_;
    wire _replicaready_[0 : PARATIL-1];
    wire [CMPLXLEN-1 : 0] _fftout_array_ [0 : PARATIL-1][0 : 2*FFTCHNL-1];
    wire [INDXLEN-1 : 0] _raddr_replica_[0:REPLICA-1];
    reg [INDXLEN-1 : 0] _raddr_replica_delay_[0:REPLICA-1];
    wire [CMPLXLEN-1 : 0] _rdata_replica_[0 : PARATIL-1][0:REPLICA-1];
    generate
        for (_til_ = 0; _til_ < PARATIL; _til_++) begin
            for (_r_ = 0; _r_ < 2*FFTCHNL; _r_++) begin
                assign _fftout_array_[_til_][_r_] = _fftout_[((_til_+1)*FFTCHNL+_r_+1)*CMPLXLEN-1 : (_til_*FFTCHNL+_r_)*CMPLXLEN];
            end
            
            buf_replica_wrapper #(
                .FFTSIZE(FFTSIZE), .FFTCHNL(FFTCHNL), .REPLICA(REPLICA), .DATALEN(DATALEN), .INDXLEN(INDXLEN)
            )buf_replica_wrapper_U(
                .clk(clk), .rstn(rstn),
                
                .invalid(_fftout_valid_[_til_]), .wrdone(_replicaready_[_til_]), .indata(_fftout_array_[_til_]),
                
                .outaddr(_raddr_replica_), .outdata(_rdata_replica_[_til_])
            );
        end
    endgenerate
    always @(posedge clk) begin
        _raddr_replica_delay_ <= _raddr_replica_;
    end
    
    /*-------- Sparse kernel index buffer --------*/ 
    wire [INDXLEN-1 : 0] _raddr_indx_;
    wire [INDXLEN-1 : 0] _rdata_indx_[0 : REPLICA-1];
    buf_index_wrapper #(
        .REPLICA(REPLICA),
        .INDXLEN(INDXLEN)
    )buf_index_wrapper_U(
        .clk(clk), .rstn(rstn),
        
        .indxvalid(indxvalid),
        .indata(indxdata),
        
        .outaddr(_raddr_indx_),
        .outdata(_raddr_replica_)
    );
    
    /*-------- Spectral kernel buffer --------*/ 
    wire [INDXLEN-1 : 0] _raddr_krn_;
    wire [CMPLXLEN+REPLLEN : 0] _rdata_krn_[0:PARAKRN-1];
    buf_kernel_wrapper #(
        .DATALEN(DATALEN), .REPLLEN(REPLLEN), .INDXLEN(INDXLEN), .PARAKRN(PARAKRN)
    )buf_kernel_wrapper_U(
        .clk(clk), .rstn(rstn),
        
        .invalid(krnlvalid||indxvalid), .iskern(krnlvalid), .issel(indxvalid), .indata(krnldata),
        .outaddr(_raddr_krn_), .outdata(_rdata_krn_)
    );
    
    /*-------- MAC array --------*/ 
    wire [INDXLEN-1 : 0] _mul_indx_[0 : PARATIL-1][0 : PARAKRN-1];
    wire [CMPLXLEN-1 : 0] _mul_input_[0 : PARATIL-1][0 : PARAKRN-1];
    wire [CMPLXLEN-1 : 0] _mul_output_[0 : PARATIL-1][0 : PARAKRN-1];
    wire [CMPLXLEN-1 : 0] _add_in_[0 : PARATIL-1][0 : PARAKRN-1];
    wire [CMPLXLEN-1 : 0] _add_out_[0 : PARATIL-1][0 : PARAKRN-1];
    wire _mul_output_valid_[0 : PARATIL-1][0 : PARAKRN-1];
    wire _inready_, _krnready_;
    genvar _k_;
    generate
    for (_til_ = 0; _til_ < PARATIL; _til_++) begin
        for (_k_ = 0; _k_ < PARAKRN; _k_++) begin
            replica_route #(
                .DATALEN(DATALEN), .REPLLEN(REPLLEN), .REPLICA(REPLICA), .INDXLEN(INDXLEN)
            )replica_route_U(
                .clk(clk), .rstn(rstn),

                .mux(_rdata_krn_[_k_][CMPLXLEN+REPLLEN-1 : CMPLXLEN]), .indata(_rdata_replica_[_til_]), .inindex(_raddr_replica_),
                
                .outindex(_mul_indx_[_til_][_k_]), .outdata(_mul_input_[_til_][_k_])
            );
            
            cmpMul_wrapper cmpMul_U(
                .clk(clk), .rstn(rstn),
                
                .s_axis_a_tvalid(_inready_), .s_axis_a_tdata(_mul_input_[_til_][_k_]), .s_axis_b_tvalid(_krnready_), .s_axis_b_tdata(_rdata_krn_[_k_][CMPLXLEN-1:0]),
                
                .m_axis_dout_tvalid(_mul_output_valid_[_til_][_k_]), .m_axis_dout_tdata(_mul_output_[_til_][_k_])
            );

            (* use_dsp48 = "yes" *) assign _add_out_[_til_][_k_][DATALEN-1 : 0] = 
                _add_in_[_til_][_k_][DATALEN-1 : 0] + _mul_output_[_til_][_k_][DATALEN-1 : 0];
            (* use_dsp48 = "yes" *) assign _add_out_[_til_][_k_][CMPLXLEN-1 : DATALEN] = 
                _add_in_[_til_][_k_][DATALEN-1 : 0] + _mul_output_[_til_][_k_][CMPLXLEN-1 : DATALEN];
        end
    end
    endgenerate

    /*-------- MAC controller --------*/ 
    wire _rdfifo_, _outready_, _convdone_;
    wire [12-1 : 0] _offsetaddrpsum_;
    control_pe #(.INDXLEN(INDXLEN)) control_pe_U(
        .clk(clk), .rstn(rstn), .start(_convstart_),
        
        .raddr_inbuf(_raddr_krn_), .raddr_index(_raddr_indx_), .inready(_inready_), .krnready(_krnready_), 
        
        .mulvalid(_mul_output_valid_[0][0]), .rdfifo(_rdfifo_), .outready(_outready_), .done(_convdone_),

        .offsetaddrpsumin(_offsetaddrpsumout_), .offsetaddrpsumout(_offsetaddrpsum_)
    );
    
    /*-------- Necessary delay line for weight index and valid --------*/ 
    // wire [INDXLEN-1 : 0] _psum_raddr_[0 : PARAKRN-1];
    // First use _mul_indx_delay1_ to read psum buffer,
    // then use _mul_indx_delay2_ to write data into psum buffer
    wire [INDXLEN-1 : 0] _mul_indx_delay1_[0 : PARAKRN-1];
    wire [INDXLEN-1 : 0] _mul_indx_delay2_[0 : PARAKRN-1];
    wire _valid_[0 : PARAKRN-1];
    wire _valid_delay_[0 : PARAKRN-1];
    delay_line #(.PARAKRN(PARAKRN), .DATALEN(INDXLEN), .DELYNUM(7))
    delay_index_U(
        .clk(clk), .rstn(rstn),
        
        .valid(_krnready_),
        .indata(_mul_indx_[0]),
        
        .outdata_after_n_minus_1(_mul_indx_delay1_),
        .outdata_after_n(_mul_indx_delay2_)
    );
    
    generate
    for (_k_ = 0; _k_ < PARAKRN; _k_=_k_+1) begin
        assign _valid_[_k_] = _rdata_krn_[_k_][CMPLXLEN+REPLLEN];
    end
    endgenerate
    delay_line #(.PARAKRN(PARAKRN), .DATALEN(1), .DELYNUM(6))
    delay_valid_U(
        .clk(clk), .rstn(rstn),
        
        .valid(_krnready_), .indata(_valid_),
        
        .outdata_after_n_minus_1(),
        .outdata_after_n(_valid_delay_)
    );

    /*-------- Collect data and index for writing --------*/ 
    // Reg data for 1 clock to give addition 1 clock to finish
    wire [INDXLEN-1 : 0] _psum_waddr_[0 : PARAKRN-1];
    wire [CMPLXLEN-1 : 0] _reg_add_out_[0 : PARATIL-1][0 : PARAKRN-1];
    wire _reg_valid_[0 : PARAKRN-1];
    reg_write #(
        .PARAKRN(PARAKRN), 
        .PARATIL(PARATIL), 
        .DATALEN(DATALEN), 
        .INDXLEN(INDXLEN)
    ) reg_write_U(
        .clk(clk),
        .rstn(rstn),

        .indata(_add_out_), .inindex(_mul_indx_delay2_), .invalid(_valid_delay_),

        .regdata(_reg_add_out_), .regindex(_psum_waddr_), .regvalid(_reg_valid_)
    );

    /*-------- Write into psum buffer --------*/
    wire [12-1 : 0] _rdaddr_ifft_;
    wire [2*DATALEN-1 : 0] _rddata_ifft_[0 : PARATIL-1][0 : PARAKRN-1];
    wire _ifftnext_;
    wire [2*DATALEN-1 : 0] _ifftin_[0 : PARATIL-1][0 : FFTCHNL-1];
    wire [PARATIL-1 : 0]_ifftvalid_;
    wire [2*DATALEN-1 : 0] _ifftout_[0 : PARATIL-1][0 : FFTCHNL-1][0 : 2-1];
    wire _ifftrd_;
    buf_psum_wrapper #(
        .INDXLEN(INDXLEN), 
        .DATALEN(DATALEN), 
        .PARATIL(PARATIL), 
        .PARAKRN(PARAKRN),
        .DEPTH(1536)
    ) buf_psum_wrapper_U(
        .clk(clk), .rstn(rstn),

        .offset(_offsetaddrpsum_),

        .we(_reg_valid_), .waddr(_psum_waddr_), .wdata(_reg_add_out_),

        .raddr(_mul_indx_delay1_), .rddata(_add_in_),

        .ifftrd(_ifftrd_), .rdaddr_ifft(_rdaddr_ifft_)
    );
    assign _rddata_ifft_ = _add_in_;

    /*-------- 2D IFFT transform --------*/
    control_ifft #(
        .INDXLEN(INDXLEN),
        .DATALEN(DATALEN),
        .PARATIL(PARATIL),
        .PARAKRN(PARAKRN),
        .FFTCHNL(FFTCHNL)
    )control_ifft_U(
        .clk(clk), .rstn(rstn),

        .ifftstart(_ifftstart_),

        .ifftrd(_ifftrd_), .rdaddr(_rdaddr_ifft_), .rddata(_rddata_ifft_),

        .ifftnext(_ifftnext_), .ifftin(_ifftin_), .ifftdone(_ifftdone_)
    );
    generate
    for (_til_ = 0; _til_ < PARATIL; _til_ = _til_+1) begin:IFFT_TILES
        ifft2D #(
            .DATALEN(DATALEN),
            .FFTCHNL(FFTCHNL)
        )(
            .clk(clk), .rstn(rstn),
    
            .invalid(_ifftnext_), .indata(_ifftin_[_til_]),
    
            .outvalid(_ifftvalid_[_til_]), .outdata(_ifftout_[_til_])
        );
    end
    endgenerate

    control_write #(
        .FFTSIZE(FFTSIZE),
        .FFTCHNL(FFTCHNL),
        .DATALEN(DATALEN),
        .PARATIL(PARATIL),
        .INDXLEN(INDXLEN)
    )control_write_U(
        .clk(clk), .rstn(rstn),

        .ifftvalid(_ifftvalid_), .ifftdata(_ifftout_),

        .axi_outvalid(axi_outvalid), .axi_outready(axi_outready), .axi_outlast(axi_outlast), .axi_outdata(axi_outdata)
    );
    
endmodule
