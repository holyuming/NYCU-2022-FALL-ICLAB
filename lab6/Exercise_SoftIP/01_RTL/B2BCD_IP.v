//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP.v
//   Module Name : B2BCD_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module B2BCD_IP #(parameter WIDTH = 4, parameter DIGIT = 2) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Declaration
// ===============================================================
input  [WIDTH-1:0]   Binary_code;
output [DIGIT*4-1:0] BCD_code;

// ===============================================================
// Soft IP DESIGN
// ===============================================================

genvar i;
integer k;
generate
for (i=0 ; i<WIDTH ; i=i+1) begin : shift_add3
    wire [DIGIT*4-1 : 0] in;
    reg  [DIGIT*4-1 : 0] out;
    if (i == 0)     
        assign in = { {(DIGIT*4 - 1){1'b0}}, Binary_code[WIDTH-1] };
    else            
        assign in = { shift_add3[i-1].out[DIGIT*4-2 : 0], Binary_code[WIDTH - 1 - i] };

    always @(*) begin
        for (k = 0 ; k<DIGIT ; k=k+1) begin
            if (i != WIDTH - 1) begin
                out[4*(k+1)-1 -: 4] = (in[4*(k+1)-1 -: 4] >= 5) ? in[4*(k+1)-1 -: 4] + 3 : in[4*(k+1)-1 -: 4];
            end
            else 
                out = in;
        end
    end
end
endgenerate

assign BCD_code = shift_add3[WIDTH - 1].out;

endmodule