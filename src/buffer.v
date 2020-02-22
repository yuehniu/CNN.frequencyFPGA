`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2019 04:43:35 PM
// Design Name: 
// Module Name: buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// On-chip buffer modules, including:
// 1, replica buffer;
// 2, weight buffer;
// 3, output buffer.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module buf_replica_wrapper #(
    parameter FFTSIZE = 8,
    parameter FFTCHNL = 8,
    parameter REPLICA = 8,
    parameter DATALEN = 16,
    parameter INDXLEN = 6,
    parameter DEPTH = 128
)(
    input clk,
    input rstn,
    
    input invalid,
    output wrdone,
    input [2*DATALEN-1 : 0] indata[0 : 2*FFTCHNL-1],
    
    input [INDXLEN-1 : 0] outaddr[0:REPLICA-1],
    output reg [2*DATALEN-1 : 0] outdata[0:REPLICA-1]
);
    localparam CMPLXLEN = 2*DATALEN;
    
    // buf control
    wire _we_;
    wire _wrdone_;
    wire [INDXLEN-1 : 0] _waddr_;
    wire [2*DATALEN-1 : 0] _wdata_;
    buf_replica_control #(
        .FFTSIZE(FFTSIZE),
        .FFTCHNL(FFTCHNL),
        .DATALEN(DATALEN),
        .INDXLEN(INDXLEN)
    ) buf_replica_control_U(
        .clk(clk),
        .rstn(rstn),
        
        .invalid(invalid), .indata(indata),
        
        .we(_we_), .wrdone(_wrdone_), .waddr(_waddr_), .wdata(_wdata_)
    );
    
    buf_replica #(
        .FFTSIZE(FFTSIZE),
        .FFTCHNL(FFTCHNL),
        .REPLICA(REPLICA),
        .DATALEN(DATALEN),
        .INDXLEN(INDXLEN),
        .DEPTH(DEPTH)
    )buf_replica_U(
        .clk(clk),
        
        .we(_we_), .indata(_wdata_), .inaddr(_waddr_),
        
        .outaddr(outaddr), .outdata(outdata)
    );
    
    
endmodule
module buf_replica_control #(
    parameter FFTSIZE = 8,
    parameter FFTCHNL = 8,
    parameter DATALEN = 16,
    parameter INDXLEN = 6
)(
    input clk,
    input rstn,
    
    input invalid,
    input [2*DATALEN-1 : 0] indata[0 : 2*FFTCHNL-1],
   
    output reg we,
    output reg wrdone,
    output reg [INDXLEN-1 : 0] waddr,
    output reg [2*DATALEN-1 : 0] wdata   
);
    localparam CMPLXLEN = 2*DATALEN;
    
    //--> replica BRAM controller
    reg [2-1 : 0] _empty_; // flag for double buffering
    reg [2-1 : 0 ] _indx_;
    reg _start_write_;
    (* ram_style = "distributed" *) reg [CMPLXLEN-1 : 0] _in_delay_[0 : 4-1][0 : 2*FFTCHNL-1];
    wire [INDXLEN-1 : 0] _waddr_;
    assign _waddr_ = waddr;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            we      <= 1'b0;
            wrdone  <= 1'b0;
            _empty_ <= 2'b11;
            _indx_  <= 2'b00;
            _start_write_ <= 1'b0;
            waddr <= {INDXLEN{1'b0}};
            wdata <= 'bx;
        end
        else begin
            we      <= 1'b0;
            wrdone  <= 1'b0;
            if (invalid) begin
                // register input values
                _indx_ <= _indx_ + 1;
                _in_delay_[_indx_]  <= indata;
                _start_write_ <= 1'b1;
            end
            if (_start_write_) begin
                we <= 1'b1;
                wdata <= _in_delay_[_waddr_[INDXLEN-1:INDXLEN-2]][_waddr_[INDXLEN-3:0]];
                
                if (waddr == {INDXLEN{1'b1}}-1) begin
                    wrdone         <= 1'b1;
                    _start_write_  <= 1'b0;
                end
            end
            if (we == 1'b1) begin
                waddr <= waddr + 1;
            end
        end
    end
endmodule

module buf_replica #(
    parameter FFTSIZE = 8,
    parameter FFTCHNL = 8,
    parameter REPLICA = 8,
    parameter DATALEN = 16,
    parameter INDXLEN = 6,
    parameter DEPTH = 128
)(
    input clk,
    input we,
    input [2*DATALEN-1 : 0] indata,
    input [INDXLEN-1 : 0] inaddr,
   
    input [INDXLEN-1 : 0] outaddr[0:REPLICA-1],
    output reg [2*DATALEN-1 : 0] outdata[0:REPLICA-1]
);
    localparam CMPLXLEN = 2*DATALEN;
    
    (* ram_style = "block" *) reg [CMPLXLEN-1 : 0] mem[0 : REPLICA-1][0 : DEPTH-1];
    reg [2*DATALEN-1 : 0] _outdata_dly_[0:REPLICA-1];
    
    integer _r_;
    always @(posedge clk) begin
        for (_r_ = 0; _r_ < REPLICA; _r_=_r_+1) begin
            _outdata_dly_[_r_] <= mem[_r_][outaddr[_r_]];
            outdata[_r_] <= _outdata_dly_[_r_];
        end
        if(we) begin
            for (_r_ = 0; _r_ < REPLICA; _r_=_r_+1) begin
                mem[_r_][inaddr] <= indata;
            end        
        end
    end
endmodule


/*
*
* On-chip buffer for kernel memory
*
*/
module buf_kernel_wrapper#(
    parameter DATALEN = 16,
    parameter REPLLEN = 4,
    parameter INDXLEN = 6,
    parameter PARAKRN = 64,
    parameter DEPTH = 256
)(
    input clk,
    input rstn,
    
    input invalid,
    input iskern,
    input issel,
    input [64-1 : 0] indata,
    
    input [INDXLEN-1 : 0] outaddr, 
    output [2*DATALEN+REPLLEN : 0] outdata[0:PARAKRN-1]
);
    localparam COMPLXLEN = 2*DATALEN;
    localparam DATASEL = COMPLXLEN+REPLLEN;
    
    wire [PARAKRN-1 : 0] _wekern_;
    wire [PARAKRN-1 : 0] _wesel_;
    wire [2*DATALEN-1 : 0] _kern_to_buf_[0:1];
    wire [REPLLEN : 0] _sel_to_buf_[0:8-1];
    wire [INDXLEN-1 : 0] _addr_;
    
    buf_kernel_control #(
        .DATALEN(DATALEN),
        .REPLLEN(REPLLEN),
        .INDXLEN(INDXLEN),
        .PARAKRN(PARAKRN)
    ) buf_kernel_control_U(
        .clk(clk), .rstn(rstn),
        
        .invalid(invalid), .iskern(iskern), .issel(issel), .indata(indata),
        .outaddr(_addr_), .wekern(_wekern_), .outkern(_kern_to_buf_), .wesel(_wesel_), .outsel(_sel_to_buf_)        
    );
    
    genvar _k_;
    generate
    for (_k_ = 0; _k_ < PARAKRN; _k_++) begin: buf_array_kernel
        buf_kernel #(
            .DATALEN(DATALEN),
            .REPLLEN(REPLLEN),
            .INDXLEN(INDXLEN),
            .PARAKRN(PARAKRN),
            .DEPTH(DEPTH)
        ) buf_kernel_U0(
            .clk(clk),
            
            .wekern(_wekern_[_k_]), .wesel(_wesel_[_k_]), .inkern(_kern_to_buf_[_k_[0]]), .insel(_sel_to_buf_[_k_[2:0]]), .inaddr(_addr_),
            
            .outaddr(outaddr), .outdata(outdata[_k_])
        );
    end
    endgenerate
endmodule
module buf_kernel #(
    parameter FFTSIZE = 8,
    parameter DATALEN = 16,
    parameter REPLLEN  = 4, // log length for #replicas
    parameter INDXLEN = 6,
    parameter PARAKRN = 64,
    parameter DEPTH = 256
)
(
    input clk,
    input wekern, // write data signal
    input wesel, // write sel signal
    input [2*DATALEN-1 : 0] inkern,
    input [REPLLEN : 0] insel,
    input [INDXLEN-1 : 0] inaddr,

    input [INDXLEN-1 : 0] outaddr,
    output reg [2*DATALEN+REPLLEN : 0] outdata
);

    localparam COMPLXLEN = 2*DATALEN;
    localparam DATASEL = COMPLXLEN+REPLLEN;

    (* ram_style="block" *) reg [COMPLXLEN-1 : 0] kernmem[0:DEPTH-1];
    (* ram_style="block" *) reg [REPLLEN : 0] selmem[0:DEPTH-1];
    reg [2*DATALEN+REPLLEN : 0] _outdata_dly_;
    reg [2*DATALEN+REPLLEN : 0] _outdata_dly2_;

    always @(posedge clk) begin
        _outdata_dly_[COMPLXLEN-1 : 0] <= kernmem[outaddr];
        _outdata_dly_[COMPLXLEN+REPLLEN : COMPLXLEN] <= selmem[outaddr];
        _outdata_dly2_ <= _outdata_dly_;
        outdata        <= _outdata_dly2_;
        // write
        if (wekern) begin
            kernmem[inaddr] <= inkern;       
        end

        if (wesel) begin
            selmem[inaddr] <= insel; 
        end
    end
    
endmodule

module buf_kernel_control #(
    parameter DATALEN = 16,
    parameter REPLLEN = 4,
    parameter INDXLEN = 6,
    parameter PARAKRN = 64
    )(
    input clk,
    input rstn,

    input invalid, // valid input coming
    input iskern, // whether input is kernel signal
    input issel, // whether input is sel signal
    input [64-1 : 0] indata,

    output reg [INDXLEN-1 : 0] outaddr,
    output reg [PARAKRN-1 : 0] wekern,
    output reg [2*DATALEN-1 : 0] outkern[0 : 1],
    output reg [PARAKRN-1 : 0] wesel,
    output reg [REPLLEN : 0] outsel[0 : 8-1]
    );
    localparam COMPLXLEN = 2 * DATALEN;
    
    reg _first_kern_,  _first_sel_;
    integer i;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _first_kern_ <= 1'b1;
            _first_sel_ <= 1'b1;
            wekern <= {PARAKRN{1'b0}};
            wesel <=  {PARAKRN{1'b0}};
            outaddr <= {INDXLEN{1'b0}};
            for (i = 0; i < 2; i++) begin
                outkern[i] <= 'bx;
            end
            for (i = 0; i < 8; i++) begin
                outsel[i]  <= 'bx;
            end
        end
        else begin
            if (invalid) begin
                if (iskern) begin                    
                    outkern[0] <= indata[31 : 0];
                    outkern[1] <= indata[63 : 32];
                    if (outaddr[3:0] == 4'b1111) begin: finish_one_kernel_write
                        outaddr <= {INDXLEN{1'b0}};
                        
                        wekern <= wekern << 2;
                    end
                    else if (wekern != {PARAKRN{1'b0}})begin
                        outaddr <= outaddr + 1;   
                    end
                    if (_first_kern_) begin
                        wekern <= {{(PARAKRN-2){1'b00}},{2'b11}};
                        _first_kern_ <= 1'b0;
                    end 
                end
                else if (issel) begin                 
                    outsel[0] <= indata[4 : 0];
                    outsel[1] <= indata[9 : 5];
                    outsel[2] <= indata[14 : 10];
                    outsel[3] <= indata[19 : 15];
                    outsel[4] <= indata[24 : 20];
                    outsel[5] <= indata[29 : 25];
                    outsel[6] <= indata[34 : 30];
                    outsel[7] <= indata[39 : 35];
                    
                    if (outaddr[3:0] == 4'b1111) begin: finish_one_sel_write
                        outaddr <= {INDXLEN{1'b0}};
                        
                        wesel <= wesel << 8;
                    end
                    else if (wesel != {PARAKRN{1'b0}})begin
                        outaddr <= outaddr + 1;
                    end
                    if (_first_sel_) begin
                        wesel <= {{(PARAKRN-8){1'b00}},{8'b1111_1111}};
                        _first_sel_ <= 1'b0;
                    end
                end
            end
        end
    end
endmodule

/*
*
* On-chip buffer for sparse kernel indices
*
*/
module buf_index_wrapper #(
    parameter REPLICA = 8,
    parameter INDXLEN = 6,
    parameter DEPTH = 128
)(
    input clk,
    input rstn,
    
    input indxvalid,
    input [64-1 : 0] indata,
    
    input [INDXLEN-1 : 0] outaddr,
    output [INDXLEN-1 : 0] outdata[0 : REPLICA-1]
);
    wire _we_;
    wire [INDXLEN-1 : 0] _waddr_;
    wire [REPLICA*INDXLEN-1 : 0] _windx_;
    buf_index_control #(
        .INDXLEN(INDXLEN),
        .REPLICA(REPLICA)
    ) buf_index_control_U(
        .clk(clk), .rstn(rstn),
        
        .indxvalid(indxvalid), .indata(indata),
        
        .we(_we_), .waddr(_waddr_), .windx(_windx_)
    );
    
    wire [REPLICA*INDXLEN-1 : 0] _outdata_;
    buf_index #(
        .REPLICA(REPLICA),
        .INDXLEN(INDXLEN),
        .DEPTH(DEPTH)
    )buf_index_U(
        .clk(clk),
        
        .we(_we_), .inaddr(_waddr_), .indata(_windx_),
        
        .outaddr(outaddr), .outdata(_outdata_)
    );
    genvar _r_;
    generate
    for (_r_ = 0; _r_ < REPLICA; _r_=_r_+1) begin
        assign outdata[_r_] = _outdata_[(_r_+1)*INDXLEN-1 : _r_*INDXLEN];
    end
    endgenerate
endmodule
module buf_index #(
    parameter REPLICA = 8,
    parameter INDXLEN = 6,
    parameter DEPTH = 128
)
(
    input clk,
    
    input we,
    input [INDXLEN-1 : 0] inaddr,
    input [REPLICA*INDXLEN-1 : 0] indata,
    
    input [INDXLEN-1 : 0] outaddr,
    output reg [REPLICA*INDXLEN-1 : 0] outdata
);
    (* ram_stype="block" *) reg [REPLICA*INDXLEN-1 : 0] mem[0 : DEPTH-1];
    
    always @(posedge clk) begin
        outdata <= mem[outaddr];
        
        if (we) begin
            mem[inaddr] <= indata;
        end
    end
endmodule

module buf_index_control #(
    parameter INDXLEN = 6,
    parameter REPLICA = 8
)(
    input clk,
    input rstn,
    
    input indxvalid,
    input [64-1 : 0] indata,
    
    output reg we,
    output reg [INDXLEN-1 : 0] waddr,
    output reg [REPLICA*INDXLEN-1 : 0] windx
);

    reg [INDXLEN-1 : 0] _waddr_;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            we <= 1'b0;
            _waddr_ <= {INDXLEN{1'b0}};
            waddr = 'bx;
            windx <= 'bx;
        end
        else begin
            we <= 1'b0;
            if (indxvalid) begin
                _waddr_ <= waddr;
                
                we <= 1'b1;
                waddr <= _waddr_;
                windx <= indata[REPLICA*INDXLEN-1 : 0];
            end
        end
    end
endmodule

/*
*
* On-chip buffer for partial sum
*
*/
module buf_psum #(
    parameter INDXLEN = 6,
    parameter DATALEN = 16,
    parameter DEPTH = 128
)
(
    input clk,
    
    input we,
    input [12-1 : 0] waddr,
    input [2*DATALEN-1 : 0] wdata,
    
    input [12-1 : 0] raddr,
    output reg [2*DATALEN-1 : 0] rdata
);
    (* ram_stype="block" *) reg [2*DATALEN-1 : 0] mem[0 : DEPTH-1];
    reg [2*DATALEN-1 : 0] _rdata_;
    always @(posedge clk) begin
        _rdata_ <= mem[raddr];
        rdata   <= _rdata_;
        
        if (we) begin
            mem[waddr] <= wdata;
        end
    end
endmodule

module buf_psum_wrapper #(
    parameter INDXLEN = 6,
    parameter DATALEN = 16,
    parameter PARATIL = 9,
    parameter PARAKRN = 64,
    parameter DEPTH = 128
)(
    input clk,
    input rstn,
    
    input [12-1 : 0] offset,
    input we[0 : PARAKRN-1], // input is valid
    input [INDXLEN-1 : 0] waddr[0 : PARAKRN-1],
    input [2*DATALEN-1 : 0] wdata[0 : PARATIL-1][0 : PARAKRN-1],

    input [INDXLEN-1 : 0] raddr[0 : PARAKRN-1],
    input ifftrd,
    input [12-1 : 0] rdaddr_ifft,
    output [2*DATALEN-1 : 0] rddata[0 : PARATIL-1][0 : PARAKRN-1]
);
    localparam CMPLXLEN = 2*DATALEN;

    generate
        genvar _til_, _k_;
        for (_til_ = 0; _til_ < PARATIL; _til_++) begin
            for (_k_ = 0; _k_ < PARAKRN; _k_++) begin
                buf_psum #(.INDXLEN(INDXLEN), .DATALEN(DATALEN), .DEPTH(DEPTH))
                buf_psum_U(
                    .clk(clk),

                    .we(we[_k_]), .waddr(waddr[_k_]+offset), .wdata(wdata[_til_][_k_]),

                    .raddr(ifftrd ? rdaddr_ifft : raddr[_k_]+offset), .rdata(rddata[_til_][_k_])
                );
            end
        end
    endgenerate
endmodule