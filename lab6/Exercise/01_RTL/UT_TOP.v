//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : UT_TOP.v
//   Module Name : UT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
//synopsys translate_on

module UT_TOP (
    // Input signals
    clk, rst_n, in_valid, in_time,
    // Output signals
    out_valid, out_display, out_day
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [30:0] in_time;
output reg out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================

localparam  S_IDLE = 0,
            S_CAL1 = 1,
            S_CAL2 = 2,
            S_CAL3 = 3,
            S_CAL4 = 4,
            S_CAL5 = 5,
            S_OUT1 = 6,
            S_OUT2 = 7,
            S_OUT3 = 8,
            S_OUT4 = 9,
            S_OUT5 = 10,
            S_OUT6 = 11,
            S_OUT7 = 12,
            S_OUT8 = 13,
            S_OUT9 = 14,
            S_OUT10 = 15,
            S_OUT11 = 16,
            S_OUT12 = 17,
            S_OUT13 = 18,
            S_OUT14 = 19;

//================================================================
// Wire & Reg Declaration
//================================================================


// fsm
reg [4:0] c_state, n_state;


// calculations
reg [30:0]  secs, n_secs;    // read from input
reg [14:0]  total_days, n_total_days;

reg [5:0]   how_many_4years, n_how_many_4years;
reg [1:0]   remain_year, n_remain_year;
reg [10:0]  year, n_year;
reg [3:0]   mon, n_mon;

reg [2:0]   fake_day;
reg [2:0]   day, n_day;     // mon ~ sun
reg [4:0]   hours, n_hours;
reg [5:0]   mins, n_mins;

reg [10:0]  BCD_sel;
wire [15:0] BCD_year, BCD_out;
wire [7:0]  BCD_mon;
wire [7:0]  BCD_day;
wire [7:0]  BCD_hour;
wire [7:0]  BCD_min;
wire [7:0]  BCD_sec;


// output
reg         n_out_valid;
reg [3:0]   n_out_display;
reg [2:0]   n_out_day;

// Soft IP
B2BCD_IP #(.WIDTH(11), .DIGIT(4)) YEAR (.Binary_code(BCD_sel), .BCD_code(BCD_out));

//================================================================
// DESIGN
//================================================================

// bcd selection
always @(*) begin
    case (c_state)
        S_CAL5, S_OUT1, S_OUT2, S_OUT3: BCD_sel = year;
        S_OUT4, S_OUT5:                 BCD_sel = {7'd0, mon};
        S_OUT6, S_OUT7:                 BCD_sel = {6'd0, total_days[4:0]};
        S_OUT8, S_OUT9:                 BCD_sel = {6'd0, hours};
        S_OUT10, S_OUT11:               BCD_sel = {5'd0, mins};
        S_OUT12, S_OUT13:               BCD_sel = {5'd0, secs[5:0]};
        default:                        BCD_sel = 0;
    endcase
end

// fsm
always @(*) begin
    case (c_state)
        S_IDLE: n_state = (in_valid == 1) ? S_CAL1 : S_IDLE;
        S_CAL1: n_state = S_CAL2;
        S_CAL2: n_state = S_CAL3;
        S_CAL3: n_state = S_CAL4;
        S_CAL4: n_state = S_CAL5;
        S_CAL5: n_state = S_OUT1;

        S_OUT1: n_state = S_OUT2;
        S_OUT2: n_state = S_OUT3;
        S_OUT3: n_state = S_OUT4;
        S_OUT4: n_state = S_OUT5;
        S_OUT5: n_state = S_OUT6;
        S_OUT6: n_state = S_OUT7;
        S_OUT7: n_state = S_OUT8;
        S_OUT8: n_state = S_OUT9;
        S_OUT9: n_state = S_OUT10;
        S_OUT10: n_state = S_OUT11;
        S_OUT11: n_state = S_OUT12;
        S_OUT12: n_state = S_OUT13;
        S_OUT13: n_state = S_OUT14;
        S_OUT14: n_state = S_IDLE;
        default: n_state = S_IDLE;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     c_state <= S_IDLE;
    else            c_state <= n_state;
end


// calculations
// seconds
always @(*) begin
    case (c_state)
        S_IDLE: n_secs = (in_valid == 1) ? in_time : 0;
        S_CAL1: n_secs = secs - total_days * 86400;
        S_CAL2: n_secs = secs[16:0] % 3600;
        S_CAL3: n_secs = secs[11:0] % 60;
        default: n_secs = secs;
    endcase
end
// days
always @(*) begin
    n_how_many_4years = total_days / 1461;
    case (c_state)
        S_IDLE: n_total_days = (in_valid == 1) ? in_time[30:7] / 675 : total_days;
        S_CAL2: n_total_days = total_days - how_many_4years * 1461;
        S_CAL4: begin
            case (remain_year)
                1: n_total_days = total_days - 365;
                2: n_total_days = total_days - 730;
                3: n_total_days = total_days - 1096;
                default: n_total_days = total_days;
            endcase
        end
        S_CAL5: begin
            if (remain_year == 2) begin
                if      (total_days < 31)  n_total_days = total_days + 1;
                else if (total_days < 60)  n_total_days = total_days - 31 + 1;
                else if (total_days < 91)  n_total_days = total_days - 60 + 1;
                else if (total_days < 121) n_total_days = total_days - 91 + 1;
                else if (total_days < 152) n_total_days = total_days - 121 + 1;
                else if (total_days < 182) n_total_days = total_days - 152 + 1;
                else if (total_days < 213) n_total_days = total_days - 182 + 1;
                else if (total_days < 244) n_total_days = total_days - 213 + 1;
                else if (total_days < 274) n_total_days = total_days - 244 + 1;
                else if (total_days < 305) n_total_days = total_days - 274 + 1;
                else if (total_days < 335) n_total_days = total_days - 305 + 1;
                else n_total_days = total_days - 335 + 1;
            end
            else begin
                if      (total_days < 31)  n_total_days = total_days + 1;
                else if (total_days < 59)  n_total_days = total_days - 31 + 1;
                else if (total_days < 90)  n_total_days = total_days - 59 + 1;
                else if (total_days < 120) n_total_days = total_days - 90 + 1;
                else if (total_days < 151) n_total_days = total_days - 120 + 1;
                else if (total_days < 181) n_total_days = total_days - 151 + 1;
                else if (total_days < 212) n_total_days = total_days - 181 + 1;
                else if (total_days < 243) n_total_days = total_days - 212 + 1;
                else if (total_days < 273) n_total_days = total_days - 243 + 1;
                else if (total_days < 304) n_total_days = total_days - 273 + 1;
                else if (total_days < 334) n_total_days = total_days - 304 + 1;
                else n_total_days = total_days - 334 + 1;
            end
        end
        default: n_total_days = total_days;
    endcase
end
always @(*) begin
    n_mon = mon;
    if (c_state == S_CAL5) begin
        if (remain_year == 2) begin
            if      (total_days < 31)  n_mon = 1;
            else if (total_days < 60)  n_mon = 2;
            else if (total_days < 91)  n_mon = 3;
            else if (total_days < 121) n_mon = 4;
            else if (total_days < 152) n_mon = 5;
            else if (total_days < 182) n_mon = 6;
            else if (total_days < 213) n_mon = 7;
            else if (total_days < 244) n_mon = 8;
            else if (total_days < 274) n_mon = 9;
            else if (total_days < 305) n_mon = 10;
            else if (total_days < 335) n_mon = 11;
            else n_mon = 12;
        end
        else begin
            if      (total_days < 31)  n_mon = 1;
            else if (total_days < 59)  n_mon = 2;
            else if (total_days < 90)  n_mon = 3;
            else if (total_days < 120) n_mon = 4;
            else if (total_days < 151) n_mon = 5;
            else if (total_days < 181) n_mon = 6;
            else if (total_days < 212) n_mon = 7;
            else if (total_days < 243) n_mon = 8;
            else if (total_days < 273) n_mon = 9;
            else if (total_days < 304) n_mon = 10;
            else if (total_days < 334) n_mon = 11;
            else n_mon = 12;
        end
    end
    else n_mon = mon;
end
// year
always @(*) begin
    if (c_state == S_CAL2)      n_year = year + {how_many_4years, 2'b00};
    else if (c_state == S_CAL4) n_year = year + remain_year;
    else                        n_year = year;

    n_remain_year = (c_state != S_CAL3)  ? remain_year : 
                    (total_days < 365)  ? 0 :
                    (total_days < 730)  ? 1 :
                    (total_days < 1096) ? 2 : 3;
end
// hours & mins
always @(*) begin
    n_hours = (c_state == S_CAL2) ? secs[16:0] / 3600 : hours;
    n_mins  = (c_state == S_CAL3) ? secs[11:0] / 60 : mins;
end
// day
always @(*) begin
    fake_day = total_days % 7;
    if (c_state == S_CAL2) begin
        case (fake_day)
            0: n_day = 4;
            1: n_day = 5;
            2: n_day = 6;
            3: n_day = 0;
            4: n_day = 1;
            5: n_day = 2;
            6: n_day = 3; 
            default: n_day = 0;
        endcase
    end
    else n_day = day;
end
// read in_time & FF
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        total_days  <= 0;
        secs        <= 0;
        hours       <= 0;
        mins        <= 0;
        day         <= 0;

        how_many_4years <= 0;
        remain_year     <= 0;
        year            <= 1970;
        mon             <= 1;
    end
    else begin
        secs        <= n_secs;
        total_days  <= (n_state == S_IDLE) ? 0 : n_total_days;
        hours       <= n_hours;
        mins        <= n_mins;
        day         <= n_day;

        how_many_4years <= n_how_many_4years;
        remain_year     <= (n_state == S_IDLE) ? 0 : n_remain_year;
        year            <= (n_state == S_IDLE) ? 1970 : n_year;
        mon             <= n_mon;
    end
end

// output
always @(*) begin
    n_out_valid = (n_state >= S_OUT1) ? 1 : 0;
    n_out_day   = (n_state >= S_OUT1) ? day : 0;
    case (n_state)
        S_OUT1:                                             n_out_display = BCD_out[15:12];
        S_OUT2:                                             n_out_display = BCD_out[11:8];
        S_OUT3, S_OUT5, S_OUT7, S_OUT9, S_OUT11, S_OUT13:   n_out_display = BCD_out[7:4];
        S_OUT4, S_OUT6, S_OUT8, S_OUT10, S_OUT12, S_OUT14:  n_out_display = BCD_out[3:0];
        default:                                            n_out_display = 0; 
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid   <= 0;
        out_display <= 0;
        out_day     <= 0;
    end
    else begin
        out_valid   <= n_out_valid;
        out_display <= n_out_display;
        out_day     <= n_out_day;
    end
end

endmodule