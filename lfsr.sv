module LFSR (
    input logic        clk,
    input logic        rstn,
    output logic [31:0] random_val
);

    logic [31:0] lfsr_reg;

    // Initialisation
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            lfsr_reg <= 32'hACE1_1234;  // Seed initial pour le LFSR
        end else begin
            lfsr_reg <= {lfsr_reg[30:0], lfsr_reg[31] ^ lfsr_reg[21] ^ lfsr_reg[1] ^ lfsr_reg[0]}; // Nouveau bit basé sur des taps
        end
    end

    // La sortie est la valeur actuelle du LFSR
    assign random_val = lfsr_reg;

endmodule
