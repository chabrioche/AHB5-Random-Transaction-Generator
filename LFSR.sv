module LFSR #(
    parameter int WIDTH = 32
)(
    input  logic clk,      // Clock signal
    input  logic rstn,     // Active-low reset signal
    output logic [WIDTH-1:0] random_val // Generated pseudo-random value
);

    logic [WIDTH-1:0] lfsr_reg, lfsr_next; // LFSR register and next state
    logic feedback; // Feedback bit

    // Primitive polynomial for a 32-bit LFSR: x^32 + x^31 + x^29 + x + 1
    always_comb begin
        feedback = lfsr_reg[WIDTH-1] ^ lfsr_reg[30] ^ lfsr_reg[28] ^ lfsr_reg[0]; // Feedback taps
        lfsr_next = {lfsr_reg[WIDTH-2:0], feedback}; // Shift and feedback
    end

    // Sequential logic for LFSR update
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            lfsr_reg <= {WIDTH{1'b1}}; // Reset to all 1s to avoid all-zero state
        end else begin
            lfsr_reg <= lfsr_next; // Update LFSR state
        end
    end

    // Output the current LFSR value
    assign random_val = lfsr_reg;

endmodule
