module AHB5_Random_Transaction_Generator (
    input  logic        HCLK,    // AHB clock signal
    input  logic        HRESETn, // Active-low reset signal for AHB
    output logic [31:0] HADDR,   // AHB address signal
    output logic [31:0] HWDATA,  // AHB write data signal
    output logic        HWRITE,  // AHB write enable signal
    output logic [2:0]  HSIZE,   // AHB transfer size signal
    output logic [2:0]  HBURST,  // AHB burst type signal
    output logic [3:0]  HPROT,   // AHB protection control signal
    output logic [1:0]  HTRANS,  // AHB transfer type signal
    input  logic        HREADY,  // AHB ready signal (indicating when the bus is ready)
    input  logic [31:0] HRDATA,  // AHB read data signal
    input  logic        HRESP    // AHB response signal
);

    // LFSR instances for generating pseudo-random values for different signals
    logic [31:0] lfsr_addr, lfsr_data, lfsr_ctrl;
    
    // Instantiate three LFSRs: one for address, one for write data, and one for control signals
    LFSR lfsr1(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_addr));   // LFSR for generating the address
    LFSR lfsr2(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_data));   // LFSR for generating write data
    LFSR lfsr3(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_ctrl));   // LFSR for generating control signals

    // Logic for generating transactions and applying them to the AHB signals
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            // Reset all AHB signals when reset is active
            HADDR   <= 32'd0;
            HWDATA  <= 32'd0;
            HWRITE  <= 1'b0;
            HSIZE   <= 3'b000;
            HBURST  <= 3'b000;
            HPROT   <= 4'b0000;
            HTRANS  <= 2'b00;
        end else if (HREADY) begin
            // When the bus is ready (HREADY = 1), generate new pseudo-random transaction values

            // Use LFSR output to generate address, data, and control signals
            HADDR  <= (lfsr_addr & 32'hFFFF_FFFF);    // Use LFSR to generate a valid 32-bit address
            HWDATA <= lfsr_data;                     // Use LFSR to generate 32-bit write data
            HWRITE <= lfsr_ctrl[0];                  // Use LFSR for randomizing between read/write (1 = write, 0 = read)
            HSIZE  <= lfsr_ctrl[2:0];                // Randomize transfer size using the LFSR (3-bit wide)
            HBURST <= lfsr_ctrl[5:3];                // Randomize burst type (3-bit wide)
            HPROT  <= lfsr_ctrl[9:6];                // Randomize protection bits (4-bit wide)
            HTRANS <= lfsr_ctrl[11:10];              // Randomize transfer type (2-bit wide)
        end
    end

endmodule
