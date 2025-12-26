// ============================================================================
// BRAM Instruction Memory
// Stores the assembly program
// ============================================================================
module bram_instruction_memory #(
    parameter ADDR_WIDTH = 10,  // 1024 instructions
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE = "program.mem"
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire read_enable,
    output reg [DATA_WIDTH-1:0] data,
    output reg ready
);

    // BRAM storage
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
    
    // Initialize from file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, memory);
        end
    end
    
    // Simple read with 1 cycle latency
    always @(posedge clk) begin
        if (read_enable) begin
            data <= memory[addr];
            ready <= 1'b1;
        end else begin
            ready <= 1'b0;
        end
    end

endmodule
