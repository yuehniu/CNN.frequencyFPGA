`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2019 11:35:26 AM
// Design Name: 
// Module Name: buf_kernel_tb
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


module buf_kernel_tb();
    localparam INDXLEN = 6;
    localparam COMPLXLEN = 32;
    localparam REPLLEN = 4;
    localparam PARAKRN = 64;
    
    reg clk, rstn;
    
    reg invalid, iskern, issel;
    reg [64-1 : 0] indata;
    
    reg [INDXLEN-1 : 0] outaddr;
    wire [COMPLXLEN+REPLLEN : 0] outdata[0 : PARAKRN-1];
    
    reg [COMPLXLEN-1 : 0] mem_kern[0: 512-1][0 : 1];
    reg [REPLLEN : 0] mem_sel[0: 128-1][0 : 8-1];
    integer i;
    integer seed = 1;
    initial begin
        #0;
        for (i = 0; i < 512; i++) begin
            mem_kern[i][0] = $random(seed);
            mem_kern[i][1] = $random(seed);
        end
    end
    initial begin
        #0;
        for (i = 0; i < 128; i++) begin
            mem_sel[i][0] = $random(seed);
            mem_sel[i][1] = $random(seed);
            mem_sel[i][2] = $random(seed);
            mem_sel[i][3] = $random(seed);
            mem_sel[i][4] = $random(seed);
            mem_sel[i][5] = $random(seed);
            mem_sel[i][6] = $random(seed);
            mem_sel[i][7] = $random(seed);
        end
    end
    
    initial begin
        #0 clk <= 0;
        #0 rstn <= 1;
        #5 rstn <= 0;
        #10 rstn <= 1;
        forever #10 clk <= ~clk;
    end
    
    reg _gen_kern_, _gen_sel_, _read_data_;
    initial begin
        #0 _gen_kern_ <= 1'b0;
        #0 _gen_sel_ <= 1'b0;
        #0 _read_data_  <= 1'b0;
        
        #50 _gen_kern_ <= 1'b1;
        
        #100;
        wait(DUT._wekern_=={PARAKRN{1'b0}});
        _gen_sel_ <= 1'b1;
        _gen_kern_ <= 1'b0;
        
        #100;
        wait(DUT._wesel_=={PARAKRN{1'b0}});
        _gen_sel_ <= 1'b0;
        _read_data_ <= 1'b1;
        
        #320;
        _read_data_ <= 1'b0;
    end
    
    initial begin
        wait(_read_data_ == 1'b1);
        wait(_read_data_ == 1'b0) $finish;
    end
    
    reg [10-1 : 0] _cnt_kern_;
    reg [10-1 : 0] _cnt_sel_;
    
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            _cnt_kern_ <= 10'd0;
            _cnt_sel_ <= 10'd0;
            
            invalid <= 1'b0;
            iskern <= 1'b0;
            issel <= 1'b0;
            indata <= 64'd0;
            
            outaddr <= 'b0;
        end
        else begin
            iskern <= 1'b0;
            issel  <= 1'b0;
            if (_gen_kern_) begin
                if (_cnt_kern_ <= 10'd512) begin
                    invalid <= 1'b1;
                    iskern <= 1'b1;
                    indata[31 : 0] <= mem_kern[_cnt_kern_][0];
                    indata[63 : 32] <= mem_kern[_cnt_kern_][1];
                    
                    _cnt_kern_ <= _cnt_kern_ + 1;
                end
            end
            else if (_gen_sel_) begin
                if (_cnt_sel_ <= 10'd128) begin
                    invalid <= 1'b1;
                    issel <= 1'b1;
                    indata[4 : 0] <= mem_sel[_cnt_sel_][0];
                    indata[9 : 5] <= mem_sel[_cnt_sel_][1];
                    indata[14 : 10] <= mem_sel[_cnt_sel_][2];
                    indata[19 : 15] <= mem_sel[_cnt_sel_][3];
                    indata[24 : 20] <= mem_sel[_cnt_sel_][4];
                    indata[29 : 25] <= mem_sel[_cnt_sel_][5];
                    indata[34 : 30] <= mem_sel[_cnt_sel_][6];
                    indata[39 : 35] <= mem_sel[_cnt_sel_][7];
                    
                    _cnt_sel_ <= _cnt_sel_ + 1;
                end
            end
            else if (_read_data_) begin
                if (outaddr < 16)
                    outaddr <= outaddr + 1;
            end
            else begin
                invalid <= 1'b0;
            end
        end
    end
    
    buf_kernel_wrapper DUT(
        .clk(clk), .rstn(rstn),
        
        .invalid(invalid), .iskern(iskern), .issel(issel), .indata(indata),
        
        .outaddr(outaddr), .outdata(outdata)
    );
    
    reg [INDXLEN-1 : 0] _outaddr_;
    always @(posedge clk) begin
        _outaddr_ <= {INDXLEN{1'b0}};
        if (_read_data_) begin
            _outaddr_  <= outaddr;
            $display("Memory check: Reference----Readout");
            for (i = 0; i < 32; i++) begin
                if (mem_kern[_outaddr_+(i*16)][0] ==  outdata[0 + (i*2)][31:0] && 
                    mem_kern[_outaddr_+(i*16)][1] ==  outdata[1 + (i*2)][31:0]) begin
                    $display("Adress %x: memory check pass.", _outaddr_);
                end
                else begin
                    $display("Adress %x: memory check failed.", _outaddr_);
                    $display("Reference: %x ---- Readout: %x", mem_kern[_outaddr_+(i*16)][0], outdata[0 + (i*2)][31:0]);
                    $display("Reference: %x ---- Readout: %x", mem_kern[_outaddr_+(i*16)][0], outdata[0 + (i*2)][31:0]);
                end
            end
            
            for (i = 0; i < 8; i++) begin
                if (mem_sel[_outaddr_+(i*16)][0] ==  outdata[0 + (i*8)][36:32] && 
                    mem_sel[_outaddr_+(i*16)][1] ==  outdata[1 + (i*8)][36:32] && 
                    mem_sel[_outaddr_+(i*16)][2] ==  outdata[2 + (i*8)][36:32] &&
                    mem_sel[_outaddr_+(i*16)][3] ==  outdata[3 + (i*8)][36:32] &&
                    mem_sel[_outaddr_+(i*16)][4] ==  outdata[4 + (i*8)][36:32] &&
                    mem_sel[_outaddr_+(i*16)][5] ==  outdata[5 + (i*8)][36:32] &&
                    mem_sel[_outaddr_+(i*16)][6] ==  outdata[6 + (i*8)][36:32] &&
                    mem_sel[_outaddr_+(i*16)][7] ==  outdata[7 + (i*8)][36:32]) begin
                    $display("Adress %x: sel check pass.", _outaddr_);
                end
                else begin
                    $display("Adress %x: sel check failed.", _outaddr_);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][0], outdata[0 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][1], outdata[1 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][2], outdata[2 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][3], outdata[3 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][4], outdata[4 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][5], outdata[5 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][6], outdata[6 + (i*8)][36:32]);
                    $display("Reference: %x ---- Readout: %x", mem_sel[_outaddr_+(i*16)][7], outdata[7 + (i*8)][36:32]);
                end
            end
        end
    end
endmodule
