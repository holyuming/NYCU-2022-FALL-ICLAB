module CHIP(    
	// Input signals
    clk,
    rst_n,
	in_valid,
    source,
    destination,
	
    // Output signals
	out_valid,
    cost
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output				out_valid;
output		[3:0]	cost;

//
wire				C_clk;
wire				C_rst_n;
wire				C_in_valid;
wire		[3:0]	C_source;
wire		[3:0]	C_destination;

wire				C_out_valid;
wire		[3:0]	C_cost;


wire				BUF_clk;
CLKBUFX20 buf0(.A(C_clk),.Y(BUF_clk));


TT u_TT(
    .clk(BUF_clk),
    .rst_n(C_rst_n),
    .in_valid(C_in_valid),
    .source(C_source),
    .destination(C_destination),
    
    .out_valid(C_out_valid),
    .cost(C_cost)
);


//
P8C I_CLK           ( .Y(C_clk),            .P(clk),            .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b0), .CSEN(1'b1) );
P8C I_RESET         ( .Y(C_rst_n),          .P(rst_n),          .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_VALID         ( .Y(C_in_valid),       .P(in_valid),       .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );

P4C I_SOURCE0       ( .Y(C_source[0]),      .P(source[0]),      .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_SOURCE1       ( .Y(C_source[1]),      .P(source[1]),      .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_SOURCE2       ( .Y(C_source[2]),      .P(source[2]),      .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_SOURCE3       ( .Y(C_source[3]),      .P(source[3]),      .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );

P4C I_DST0          ( .Y(C_destination[0]), .P(destination[0]), .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_DST1          ( .Y(C_destination[1]), .P(destination[1]), .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_DST2          ( .Y(C_destination[2]), .P(destination[2]), .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );
P4C I_DST3          ( .Y(C_destination[3]), .P(destination[3]), .A(1'b0), .ODEN(1'b0), .OCEN(1'b0), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0) );

P8C O_VALID         ( .A(C_out_valid), 	    .P(out_valid),  .ODEN(1'b1), .OCEN(1'b1), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0));
P8C O_COST0         ( .A(C_cost[0]),        .P(cost[0]),    .ODEN(1'b1), .OCEN(1'b1), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0));
P8C O_COST1         ( .A(C_cost[1]),        .P(cost[1]),    .ODEN(1'b1), .OCEN(1'b1), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0));
P8C O_COST2         ( .A(C_cost[2]),        .P(cost[2]),    .ODEN(1'b1), .OCEN(1'b1), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0));
P8C O_COST3         ( .A(C_cost[3]),        .P(cost[3]),    .ODEN(1'b1), .OCEN(1'b1), .PU(1'b1), .PD(1'b0), .CEN(1'b1), .CSEN(1'b0));


//I/O power 3.3V pads x? (DVDD + DGND)
PVDDR VDDP0 ();
PVSSR GNDP0 ();
PVDDR VDDP1 ();
PVSSR GNDP1 ();
PVDDR VDDP2 ();
PVSSR GNDP2 ();
PVDDR VDDP3 ();
PVSSR GNDP3 ();

//Core poweri 1.8V pads x? (VDD + GND)
PVDDC VDDC0 ();
PVSSC GNDC0 ();
PVDDC VDDC1 ();
PVSSC GNDC1 ();
PVDDC VDDC2 ();
PVSSC GNDC2 ();
PVDDC VDDC3 ();
PVSSC GNDC3 ();

endmodule