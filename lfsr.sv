module LFSR (
    input logic        clk,      // Clock signal
    input logic        rstn,     // Active-low reset signal
    output logic [31:0] random_val // 32-bit random value output from the LFSR
);

    logic [31:0] lfsr_reg;  // 32-bit LFSR register

    // Shift register logic with feedback taps for pseudo-random generation
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // On reset, initialize the LFSR with a seed value
            lfsr_reg <= 32'hACE1_1234;
        end else begin
            // LFSR feedback calculation: shifts the bits and applies XOR on certain taps
            lfsr_reg <= {lfsr_reg[30:0], lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0]};
        end
    end

    // Assign the current LFSR value to the output
    assign random_val = lfsr_reg;

endmodule
