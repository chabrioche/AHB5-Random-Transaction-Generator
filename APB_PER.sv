module apb_per #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic              PCLK,       // APB clock signal
    input  logic              PRESETn,    // APB reset signal (active low)
    input  logic [ADDR_WIDTH-1:0] PADDR,  // APB address
    input  logic [DATA_WIDTH-1:0] PWDATA, // APB write data
    input  logic              PWRITE,     // APB write enable signal
    input  logic              PSEL,       // APB select signal
    input  logic              PENABLE,    // APB enable signal
    output logic [DATA_WIDTH-1:0] PRDATA, // APB read data
    output logic              PSLVERROR,  // APB slave error signal
    output logic              PREADY      // APB ready signal
);

    // Internal memory to store data (256 entries)
    logic [DATA_WIDTH-1:0] memory [0:255];

    // APB response logic
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA     <= 32'h0;     // Reset the read data
            PSLVERROR  <= 1'b0;      // No error on reset
            PREADY     <= 1'b1;      // Peripheral is always ready
        end else if (PSEL && PENABLE) begin
            PREADY <= 1'b1;          // Peripheral is ready to respond
            if (PWRITE) begin
                memory[PADDR] <= PWDATA;  // Write operation to memory
            end else begin
                PRDATA <= memory[PADDR];  // Read operation from memory
            end
        end else begin
            PREADY <= 1'b1;          // Maintain ready signal
        end
    end

endmodule
