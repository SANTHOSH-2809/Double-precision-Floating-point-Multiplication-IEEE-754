`timescale 1ns / 1ps

// ============================================================================
// IEEE-754 Binary64 Floating-Point Multiplier
//
// Binary64:
//   [63]    Sign
//   [62:52] Exponent
//   [51:0]  Fraction
//
// Features:
//   - Normal and subnormal operands
//   - Zero, Infinity, NaN
//   - Signaling-NaN detection and quieting
//   - NaN payload preservation
//   - Exact 53 x 53 significand multiplication
//   - Normalization
//   - Guard / Round / Sticky bits
//   - Five IEEE-754 rounding directions supported
//   - Gradual underflow
//   - Overflow handling
//   - invalid / overflow / underflow / inexact flags
//
// Rounding mode:
//   3'b000 : RoundTiesToEven
//   3'b001 : RoundTowardZero
//   3'b010 : RoundTowardPositive
//   3'b011 : RoundTowardNegative
//   3'b100 : RoundTiesToAway
//
// Combinational RTL. Intended for synthesis/simulation.
// ============================================================================

module floatingpoint_ieee (
    input  [63:0] A,
    input  [63:0] B,
    input  [2:0]  rounding_mode,

    output reg [63:0] final_product,

    output reg invalid,
    output reg overflow,
    output reg underflow,
    output reg inexact
);

    localparam [2:0] RM_RNE = 3'b000;
    localparam [2:0] RM_RTZ = 3'b001;
    localparam [2:0] RM_RUP = 3'b010;
    localparam [2:0] RM_RDN = 3'b011;
    localparam [2:0] RM_RNA = 3'b100;

    // ------------------------------------------------------------------------
    // Input fields
    // ------------------------------------------------------------------------

    reg        sign_a;
    reg        sign_b;
    reg        sign_r;

    reg [10:0] exp_a;
    reg [10:0] exp_b;

    reg [51:0] frac_a;
    reg [51:0] frac_b;

    // ------------------------------------------------------------------------
    // Classification
    // ------------------------------------------------------------------------

    reg a_nan;
    reg b_nan;

    reg a_snan;
    reg b_snan;

    reg a_inf;
    reg b_inf;

    reg a_zero;
    reg b_zero;

    reg a_subnormal;
    reg b_subnormal;

    // ------------------------------------------------------------------------
    // Internally normalized operands
    //
    // Normal:
    //     mant = 1.fraction
    //     exp  = encoded_exp - 1023
    //
    // Subnormal:
    //     fraction is shifted until bit 52 is the leading 1
    //     effective exponent is adjusted accordingly
    // ------------------------------------------------------------------------

    reg [52:0] mant_a;
    reg [52:0] mant_b;

    reg signed [12:0] exp_a_eff;
    reg signed [12:0] exp_b_eff;

    // ------------------------------------------------------------------------
    // Exact product
    // ------------------------------------------------------------------------

    reg [105:0] mant_prod;

    reg signed [12:0] exp_sum;
    reg signed [12:0] exp_norm;
    reg signed [12:0] exp_round;

    reg norm_shift;

    // ------------------------------------------------------------------------
    // Rounding datapath
    // ------------------------------------------------------------------------

    reg [127:0] shifted_product;

    reg [52:0] sig_trunc;
    reg [53:0] sig_round_ext;

    reg [51:0] frac_trunc;
    reg [52:0] sub_round;

    reg guard_bit;
    reg round_bit;
    reg sticky_bit;

    reg round_increment;

    reg [10:0] exp_field;

    reg tiny_before_round;

    integer i;
    integer shift_a;
    integer shift_b;
    integer shift_total;

    reg found_one;

    // =========================================================================
    // COMBINATIONAL DATAPATH
    // =========================================================================

    always @* begin

        // ---------------------------------------------------------------------
        // Defaults
        // ---------------------------------------------------------------------

        final_product = 64'd0;

        invalid   = 1'b0;
        overflow  = 1'b0;
        underflow = 1'b0;
        inexact   = 1'b0;

        sign_a = A[63];
        sign_b = B[63];
        sign_r = sign_a ^ sign_b;

        exp_a = A[62:52];
        exp_b = B[62:52];

        frac_a = A[51:0];
        frac_b = B[51:0];

        // ---------------------------------------------------------------------
        // Classification
        // ---------------------------------------------------------------------

        a_nan = (exp_a == 11'h7FF) && (frac_a != 52'd0);
        b_nan = (exp_b == 11'h7FF) && (frac_b != 52'd0);

        // Binary64 quiet/signaling NaN distinction:
        // fraction[51] = 1 -> quiet NaN
        // fraction[51] = 0 -> signaling NaN
        a_snan = a_nan && !frac_a[51];
        b_snan = b_nan && !frac_b[51];

        a_inf = (exp_a == 11'h7FF) && (frac_a == 52'd0);
        b_inf = (exp_b == 11'h7FF) && (frac_b == 52'd0);

        a_zero = (exp_a == 11'd0) && (frac_a == 52'd0);
        b_zero = (exp_b == 11'd0) && (frac_b == 52'd0);

        a_subnormal = (exp_a == 11'd0) && (frac_a != 52'd0);
        b_subnormal = (exp_b == 11'd0) && (frac_b != 52'd0);

        // ---------------------------------------------------------------------
        // Default internal values
        // ---------------------------------------------------------------------

        mant_a = 53'd0;
        mant_b = 53'd0;

        exp_a_eff = 13'sd0;
        exp_b_eff = 13'sd0;

        mant_prod = 106'd0;

        exp_sum = 13'sd0;
        exp_norm = 13'sd0;
        exp_round = 13'sd0;

        norm_shift = 1'b0;

        shifted_product = 128'd0;

        sig_trunc = 53'd0;
        sig_round_ext = 54'd0;

        frac_trunc = 52'd0;
        sub_round = 53'd0;

        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;

        round_increment = 1'b0;

        exp_field = 11'd0;

        tiny_before_round = 1'b0;

        shift_a = 0;
        shift_b = 0;
        shift_total = 0;

        found_one = 1'b0;

        // ---------------------------------------------------------------------
        // Decode/normalize operand A
        // ---------------------------------------------------------------------

        if (!a_nan && !a_inf && !a_zero) begin

            if (!a_subnormal) begin

                // Normal:
                // value = (mant_a / 2^52) * 2^exp_a_eff

                mant_a = {1'b1, frac_a};

                exp_a_eff =
                    $signed({1'b0, exp_a}) - 13'sd1023;

            end
            else begin

                // Find leading 1 in the 52-bit fraction.
                shift_a = 0;
                found_one = 1'b0;

                for (i = 51; i >= 0; i = i - 1) begin
                    if (!found_one && frac_a[i]) begin
                        shift_a = 52 - i;
                        found_one = 1'b1;
                    end
                end

                // Move the leading 1 to bit 52.
                mant_a = {1'b0, frac_a} << shift_a;

                // A subnormal is normalized internally to:
                // 1.x * 2^effective_exponent
                exp_a_eff =
                    -13'sd1022 - shift_a;

            end
        end

        // ---------------------------------------------------------------------
        // Decode/normalize operand B
        // ---------------------------------------------------------------------

        if (!b_nan && !b_inf && !b_zero) begin

            if (!b_subnormal) begin

                mant_b = {1'b1, frac_b};

                exp_b_eff =
                    $signed({1'b0, exp_b}) - 13'sd1023;

            end
            else begin

                shift_b = 0;
                found_one = 1'b0;

                for (i = 51; i >= 0; i = i - 1) begin
                    if (!found_one && frac_b[i]) begin
                        shift_b = 52 - i;
                        found_one = 1'b1;
                    end
                end

                mant_b = {1'b0, frac_b} << shift_b;

                exp_b_eff =
                    -13'sd1022 - shift_b;

            end
        end

        // ---------------------------------------------------------------------
        // Exponent addition + exact significand multiplication
        // ---------------------------------------------------------------------

        exp_sum = exp_a_eff + exp_b_eff;

        mant_prod = mant_a * mant_b;

        // ---------------------------------------------------------------------
        // INVALID exception
        // ---------------------------------------------------------------------

        if (a_snan || b_snan)
            invalid = 1'b1;

        if ((a_inf && b_zero) || (a_zero && b_inf))
            invalid = 1'b1;

        // =====================================================================
        // SPECIAL CASE PRIORITY
        // =====================================================================

        // ---------------------------------------------------------------------
        // NaN
        // Quiet NaN and preserve payload.
        // ---------------------------------------------------------------------

        if (a_nan) begin

            final_product =
                {1'b0,
                 11'h7FF,
                 1'b1,
                 frac_a[50:0]};

        end
        else if (b_nan) begin

            final_product =
                {1'b0,
                 11'h7FF,
                 1'b1,
                 frac_b[50:0]};

        end

        // ---------------------------------------------------------------------
        // Infinity * zero = NaN, invalid
        // ---------------------------------------------------------------------

        else if ((a_inf && b_zero) ||
                 (a_zero && b_inf)) begin

            final_product = 64'h7FF8_0000_0000_0000;

        end

        // ---------------------------------------------------------------------
        // Infinity * non-zero finite, or infinity * infinity
        // ---------------------------------------------------------------------

        else if (a_inf || b_inf) begin

            final_product =
                {sign_r,
                 11'h7FF,
                 52'd0};

        end

        // ---------------------------------------------------------------------
        // Zero * finite
        // ---------------------------------------------------------------------

        else if (a_zero || b_zero) begin

            final_product =
                {sign_r,
                 63'd0};

        end

        // =====================================================================
        // FINITE NON-ZERO MULTIPLICATION
        // =====================================================================

        else begin

            // Product of normalized significands lies in [1,4).
            // mant_prod[105] = 1 means the product is in [2,4).
            norm_shift = mant_prod[105];

            exp_norm =
                exp_sum +
                (norm_shift ? 13'sd1 : 13'sd0);

            // -----------------------------------------------------------------
            // Determine whether the result is below the minimum normal
            // exponent (-1022).
            // -----------------------------------------------------------------

            tiny_before_round =
                (exp_norm < -13'sd1022);

            // -----------------------------------------------------------------
            // Base shift needed to obtain:
            //     [hidden-bit + 52 fraction bits]
            //
            // norm_shift = 0:
            //     retain product[104:52]
            //     discard below bit 52
            //
            // norm_shift = 1:
            //     retain product[105:53]
            //     discard below bit 53
            // -----------------------------------------------------------------

            if (norm_shift)
                shift_total = 53;
            else
                shift_total = 52;

            // For gradual underflow, shift farther right by the exponent
            // deficit below -1022.
            if (tiny_before_round)
                shift_total = shift_total + (-1022 - exp_norm);

            // If everything in the product is shifted out, the result is
            // either zero or one minimum-subnormal unit after rounding.
            if (shift_total > 127) begin

                shifted_product = 128'd0;

            end
            else begin

                shifted_product =
                    {22'd0, mant_prod} >> shift_total;

            end

            // -----------------------------------------------------------------
            // Retained bits
            // -----------------------------------------------------------------

            sig_trunc = shifted_product[52:0];
            frac_trunc = shifted_product[51:0];

            // -----------------------------------------------------------------
            // Guard / Round / Sticky
            //
            // For shifts <= 106:
            //   G = product[shift_total-1]
            //   R = product[shift_total-2]
            //   S = OR(product[shift_total-3:0])
            //
            // For shifts > 106, no product bit exists at G/R positions;
            // all actual product bits are part of the sticky region.
            // -----------------------------------------------------------------

            guard_bit = 1'b0;
            round_bit = 1'b0;
            sticky_bit = 1'b0;

            if (shift_total >= 1 && shift_total <= 106)
                guard_bit = mant_prod[shift_total - 1];

            if (shift_total >= 2 && shift_total <= 107)
                round_bit = mant_prod[shift_total - 2];

            if (shift_total >= 3) begin

                if (shift_total - 3 >= 105) begin
                    sticky_bit = |mant_prod;
                end
                else begin
                    sticky_bit = 1'b0;

                    for (i = 0; i < 106; i = i + 1) begin
                        if (i <= shift_total - 3)
                            sticky_bit = sticky_bit | mant_prod[i];
                    end
                end

            end

            // -----------------------------------------------------------------
            // Inexact
            // -----------------------------------------------------------------

            inexact =
                guard_bit |
                round_bit |
                sticky_bit;

            // -----------------------------------------------------------------
            // Rounding increment
            // -----------------------------------------------------------------

            round_increment = 1'b0;

            case (rounding_mode)

                // RoundTiesToEven
                RM_RNE: begin
                    if (guard_bit &&
                        (round_bit ||
                         sticky_bit ||
                         sig_trunc[0]))
                        round_increment = 1'b1;
                end

                // RoundTowardZero
                RM_RTZ: begin
                    round_increment = 1'b0;
                end

                // RoundTowardPositive
                RM_RUP: begin
                    round_increment =
                        (!sign_r) && inexact;
                end

                // RoundTowardNegative
                RM_RDN: begin
                    round_increment =
                        sign_r && inexact;
                end

                // RoundTiesToAway
                RM_RNA: begin
                    if (guard_bit)
                        round_increment = 1'b1;
                end

                // Safe default: RNE
                default: begin
                    if (guard_bit &&
                        (round_bit ||
                         sticky_bit ||
                         sig_trunc[0]))
                        round_increment = 1'b1;
                end

            endcase

            // =================================================================
            // NORMAL RESULT
            // =================================================================

            if (!tiny_before_round) begin

                // Use 54 bits so a significand rounding carry is not lost.
                sig_round_ext =
                    {1'b0, sig_trunc} +
                    (round_increment ? 54'd1 : 54'd0);

                exp_round = exp_norm;

                // 1.111... + 1 ulp -> 10.000...
                if (sig_round_ext[53]) begin

                    sig_round_ext = 54'h20000000000000;

                    exp_round =
                        exp_norm + 13'sd1;

                end

                // -----------------------------------------------------------------
                // Overflow
                // -----------------------------------------------------------------

                if (exp_round > 13'sd1023) begin

                    overflow = 1'b1;
                    inexact  = 1'b1;

                    // RNE/RNA -> infinity.
                    // Directed rounding toward the sign -> infinity.
                    // Other cases -> largest finite.
                    if ((rounding_mode == RM_RNE) ||
                        (rounding_mode == RM_RNA) ||
                        ((rounding_mode == RM_RUP) && !sign_r) ||
                        ((rounding_mode == RM_RDN) && sign_r)) begin

                        final_product =
                            {sign_r,
                             11'h7FF,
                             52'd0};

                    end
                    else begin

                        final_product =
                            {sign_r,
                             11'h7FE,
                             52'hFFFF_FFFF_FFFFF};

                    end

                end
                else begin

                    exp_field =
                        exp_round + 13'sd1023;

                    final_product =
                        {sign_r,
                         exp_field,
                         sig_round_ext[51:0]};

                end

            end

            // =================================================================
            // SUBNORMAL / GRADUAL UNDERFLOW
            // =================================================================

            else begin

                // The retained subnormal fraction is 52 bits.
                sub_round =
                    {1'b0, frac_trunc} +
                    (round_increment ? 53'd1 : 53'd0);

                // Rounding can create exactly the minimum normal number.
                if (sub_round[52]) begin

                    final_product =
                        {sign_r,
                         11'd1,
                         52'd0};

                    // Using tininess-after-rounding:
                    // result is now normal, so underflow is not raised.
                    underflow = 1'b0;

                end
                else begin

                    final_product =
                        {sign_r,
                         11'd0,
                         sub_round[51:0]};

                    // Tiny + inexact -> underflow.
                    underflow = inexact;

                end

            end

        end

    end

endmodule


// ============================================================================
// Backward-compatible wrapper
//
// Original project interface:
//
//     floatingpoint(A, B, final_product)
//
// Fixed to RoundTiesToEven. Exception flags are intentionally not exposed.
// ============================================================================

module floatingpoint (
    input  [63:0] A,
    input  [63:0] B,
    output [63:0] final_product
);

    wire invalid_unused;
    wire overflow_unused;
    wire underflow_unused;
    wire inexact_unused;

    floatingpoint_ieee u_fp (
        .A(A),
        .B(B),
        .rounding_mode(3'b000),
        .final_product(final_product),
        .invalid(invalid_unused),
        .overflow(overflow_unused),
        .underflow(underflow_unused),
        .inexact(inexact_unused)
    );

endmodule




