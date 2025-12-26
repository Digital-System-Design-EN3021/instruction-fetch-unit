// ============================================================================
// Comprehensive Verification Environment for Instruction Fetch Unit
// Includes: Testbench, Scoreboard, Coverage, Assertions, and Test Cases
// ============================================================================

// ============================================================================
// Instruction Memory Model with Realistic Behavior
// ============================================================================
module instruction_memory #(
    parameter MEM_SIZE = 1024,
    parameter LATENCY = 1  // Memory access latency in cycles
)(
    input wire clk,
    input wire rst_n,
    input wire [31:0] addr,
    input wire read_enable,
    output reg [31:0] data,
    output reg ready
);

    reg [31:0] memory [0:MEM_SIZE-1];
    reg [3:0] latency_counter;
    reg request_pending;
    reg [31:0] pending_addr;
    
    integer i;
    
    // Initialize memory with test instructions
    initial begin
        // Sequential instructions
        for (i = 0; i < 64; i = i + 1) begin
            memory[i] = 32'h00100000 | (i << 8); // ADDI pattern
        end
        
        // Branch instruction at address 0x40 (index 16)
        memory[16] = 32'h10000008; // BEQ (branch if equal)
        
        // Branch target at 0x100 (index 64)
        for (i = 64; i < 128; i = i + 1) begin
            memory[i] = 32'h00200000 | (i << 8); // Different pattern
        end
        
        // Another branch at 0x80 (index 32)
        memory[32] = 32'h14000004; // BNE (branch if not equal)
    end
    
    // Memory access with latency
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data <= 32'h0;
            ready <= 1'b0;
            latency_counter <= 0;
            request_pending <= 1'b0;
        end else begin
            if (read_enable && !request_pending) begin
                // New request
                request_pending <= 1'b1;
                pending_addr <= addr;
                latency_counter <= LATENCY;
                ready <= 1'b0;
            end else if (request_pending) begin
                if (latency_counter > 0) begin
                    latency_counter <= latency_counter - 1;
                    ready <= 1'b0;
                end else begin
                    // Serve the request
                    data <= memory[pending_addr[11:2]]; // Word-aligned
                    ready <= 1'b1;
                    request_pending <= 1'b0;
                end
            end else begin
                ready <= 1'b0;
            end
        end
    end

endmodule

