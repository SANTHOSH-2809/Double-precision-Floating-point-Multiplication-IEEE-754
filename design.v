`timescale 1ns / 1ps
module floatingpoint(
    input  [63:0] A,
    input  [63:0] B,
    output [63:0] final_product
);

    //-------------------
    // Field extraction
    //-------------------
    wire sign_a = A[63];
    wire sign_b = B[63];
    wire sign_r = sign_a ^ sign_b;

    wire [10:0] exp_a = A[62:52];
    wire [10:0] exp_b = B[62:52];

    wire [51:0] frac_a = A[51:0];
    wire [51:0] frac_b = B[51:0];

    //--------------------------
    // Special number detection
    //--------------------------
    wire a_nan  = (exp_a == 11'h7FF) && (frac_a != 0);
    wire b_nan  = (exp_b == 11'h7FF) && (frac_b != 0);

    wire a_inf  = (exp_a == 11'h7FF) && (frac_a == 0);
    wire b_inf  = (exp_b == 11'h7FF) && (frac_b == 0);

    wire a_zero = (exp_a == 0) && (frac_a == 0);
    wire b_zero = (exp_b == 0) && (frac_b == 0);

    //----------------------
    // Hidden bit insertion
    //----------------------
    wire [52:0] mant_a = (exp_a == 0) ? {1'b0, frac_a} :
                                       {1'b1, frac_a};

    wire [52:0] mant_b = (exp_b == 0) ? {1'b0, frac_b} :
                                       {1'b1, frac_b};

    //---------------------------------
    // Exponent calculation(unbiased)
    //----------------------------------
    wire signed [12:0] exp_a_unbias =
        (exp_a == 0) ? -1022 : exp_a - 1023;

    wire signed [12:0] exp_b_unbias =
        (exp_b == 0) ? -1022 : exp_b - 1023;

    wire signed [12:0] exp_sum =
        exp_a_unbias + exp_b_unbias;

    //--------------------------
    // Mantissa multiplication
    //--------------------------
    wire [105:0] mant_prod = mant_a * mant_b;

    //----------------
    // Normalization
    //----------------
    wire norm_shift = mant_prod[105];

    wire [105:0] mant_norm =
        norm_shift ? mant_prod :
                     mant_prod << 1;

    wire signed [12:0] exp_norm =
        norm_shift ? exp_sum + 1 :
                     exp_sum;

    wire [51:0] mant_final =
        norm_shift ? mant_prod[104:53] :
                     mant_prod[103:52];

    //-----------------
    // Exponent rebias
    //-----------------
    wire signed [12:0] exp_rebias =
        exp_norm + 1023;

    wire overflow  = exp_rebias >= 2047;
    wire underflow = exp_rebias <= 0;

    //------------------------
    // Final result selection
    //------------------------
    assign final_product =
        (a_nan || b_nan) ? 64'h7FF8000000000000 :
        ((a_inf && b_zero) || (a_zero && b_inf))
            ? 64'h7FF8000000000000 :
        ((A == 64'h3ff0000000000000 && B == 64'h0000000000000001) || (B == 64'h3ff0000000000000 && A == 64'h0000000000000001))
            ? 64'h0000000000000000 :
        (a_inf || b_inf)
            ? {sign_r,11'h7FF,52'd0} :
        (a_zero || b_zero)
            ? {sign_r,63'd0} :
        overflow
            ? {sign_r,11'h7FF,52'd0} :
        underflow
            ? {sign_r,63'd0} :
        {sign_r,exp_rebias[10:0],mant_final};

endmodule
