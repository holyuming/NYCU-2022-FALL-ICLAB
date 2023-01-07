//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP_demo.v
//   Module Name : B2BCD_IP_demo
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
//synopsys translate_on

module B2BCD_IP_demo #(parameter WIDTH = 4, parameter DIGIT = 2) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input  [WIDTH-1:0]   Binary_code;
output [DIGIT*4-1:0] BCD_code;

// ===============================================================
// Soft IP
// ===============================================================
B2BCD_IP #(.WIDTH(WIDTH), .DIGIT(DIGIT)) I_B2BCD_IP ( .Binary_code(Binary_code), .BCD_code(BCD_code) );


endmodule