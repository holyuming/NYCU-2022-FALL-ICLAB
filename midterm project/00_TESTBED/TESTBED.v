`timescale 1ns/1ps

`include "PATTERN.v"
`ifdef RTL
    `include "EDH.v"
`endif

`ifdef GATE
    `include "EDH_SYN.v"
`endif

module TESTBED();
parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;
//Connection wires
wire			  clk,rst_n;
wire			  in_valid;
wire [1:0] 		  op;
wire [3:0]        pic_no;     
wire [5:0]        se_no;     
wire              busy;          

// axi write address channel 
wire [ID_WIDTH-1:0]     awid_m_inf;
wire [ADDR_WIDTH-1:0] awaddr_m_inf;
wire [2:0]            awsize_m_inf;
wire [1:0]           awburst_m_inf;
wire [7:0]             awlen_m_inf;
wire                 awvalid_m_inf;
wire                 awready_m_inf;
// axi write data channel 
wire [DATA_WIDTH-1:0]  wdata_m_inf;
wire                   wlast_m_inf;
wire                  wvalid_m_inf;
wire                  wready_m_inf;
// axi write response channel
wire [ID_WIDTH-1:0]      bid_m_inf;
wire [1:0]             bresp_m_inf;
wire                  bvalid_m_inf;
wire                  bready_m_inf;
// -----------------------------
// axi read address channel 
wire    [ID_WIDTH-1:0]      arid_m_inf;
wire    [ADDR_WIDTH-1:0]  araddr_m_inf;
wire    [7:0]              arlen_m_inf;
wire    [2:0]             arsize_m_inf;
wire    [1:0]            arburst_m_inf;
wire                     arvalid_m_inf;
wire                     arready_m_inf;
// -----------------------------
// axi read data channel 
wire [ID_WIDTH-1:0]          rid_m_inf;
wire [DATA_WIDTH-1:0]      rdata_m_inf;
wire [1:0]                 rresp_m_inf;
wire                       rlast_m_inf;
wire                      rvalid_m_inf;
wire                      rready_m_inf;
// -----------------------------

// initial
initial begin
	`ifdef RTL
		// $fsdbDumpfile("EDH.fsdb");
		// $fsdbDumpvars(0,"+mda");
		// $fsdbDumpvars();
	`endif
	`ifdef GATE
		$sdf_annotate("EDH_SYN.sdf", MY_DESIGN);
		// $fsdbDumpfile("EDH_SYN.fsdb");
		// $fsdbDumpvars();
	`endif
end


// design 
EDH MY_DESIGN (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .op(op),
    .pic_no(pic_no),
    .se_no(se_no),
    .busy(busy),

    .awid_m_inf(awid_m_inf),
    .awaddr_m_inf(awaddr_m_inf),
    .awsize_m_inf(awsize_m_inf),
    .awburst_m_inf(awburst_m_inf),
    .awlen_m_inf(awlen_m_inf),
    .awvalid_m_inf(awvalid_m_inf),
    .awready_m_inf(awready_m_inf),

    .wdata_m_inf(wdata_m_inf),
    .wlast_m_inf(wlast_m_inf),
    .wvalid_m_inf(wvalid_m_inf),
    .wready_m_inf(wready_m_inf),

    .bid_m_inf(bid_m_inf),
    .bresp_m_inf(bresp_m_inf),
    .bvalid_m_inf(bvalid_m_inf),
    .bready_m_inf(bready_m_inf),

    .arid_m_inf(arid_m_inf),
    .araddr_m_inf(araddr_m_inf),
    .arlen_m_inf(arlen_m_inf),
    .arsize_m_inf(arsize_m_inf),
    .arburst_m_inf(arburst_m_inf),
    .arvalid_m_inf(arvalid_m_inf),
    .arready_m_inf(arready_m_inf),

    .rid_m_inf(rid_m_inf),
    .rdata_m_inf(rdata_m_inf),
    .rresp_m_inf(rresp_m_inf),
    .rlast_m_inf(rlast_m_inf),
    .rvalid_m_inf(rvalid_m_inf),
    .rready_m_inf(rready_m_inf)
);


// pattern
PATTERN My_PATTERN (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .op(op),
    .pic_no(pic_no),
    .se_no(se_no),
    .busy(busy),

    .awid_s_inf(awid_m_inf),
    .awaddr_s_inf(awaddr_m_inf),
    .awsize_s_inf(awsize_m_inf),
    .awburst_s_inf(awburst_m_inf),
    .awlen_s_inf(awlen_m_inf),
    .awvalid_s_inf(awvalid_m_inf),
    .awready_s_inf(awready_m_inf),

    .wdata_s_inf(wdata_m_inf),
    .wlast_s_inf(wlast_m_inf),
    .wvalid_s_inf(wvalid_m_inf),
    .wready_s_inf(wready_m_inf),

    .bid_s_inf(bid_m_inf),
    .bresp_s_inf(bresp_m_inf),
    .bvalid_s_inf(bvalid_m_inf),
    .bready_s_inf(bready_m_inf),

    .arid_s_inf(arid_m_inf),
    .araddr_s_inf(araddr_m_inf),
    .arlen_s_inf(arlen_m_inf),
    .arsize_s_inf(arsize_m_inf),
    .arburst_s_inf(arburst_m_inf),
    .arvalid_s_inf(arvalid_m_inf),
    .arready_s_inf(arready_m_inf),

    .rid_s_inf(rid_m_inf),
    .rdata_s_inf(rdata_m_inf),
    .rresp_s_inf(rresp_m_inf),
    .rlast_s_inf(rlast_m_inf),
    .rvalid_s_inf(rvalid_m_inf),
    .rready_s_inf(rready_m_inf)
);

endmodule