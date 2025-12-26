// ============================================================================
// Assertion Checker - SVA-style assertions in Verilog
// ============================================================================
module assertion_checker(
    input wire clk,
    input wire rst_n,
    input wire [31:0] pc,
    input wire instruction_valid,
    input wire prefetch_full,
    input wire prefetch_empty,
    input wire mem_read,
    input wire branch_resolved,
    input wire flush
);

    // Property: PC should be word-aligned
    always @(posedge clk) begin
        if (rst_n && instruction_valid) begin
            if (pc[1:0] != 2'b00) begin
                $display("[ASSERTION FAIL] PC not word-aligned: 0x%h", pc);
                $fatal(1, "PC alignment violation");
            end
        end
    end
    
    // Property: Cannot be both full and empty
    always @(posedge clk) begin
        if (rst_n && prefetch_full && prefetch_empty) begin
            $display("[ASSERTION FAIL] Prefetch buffer is both full and empty");
            $fatal(1, "Buffer state violation");
        end
    end
    
    // Property: Should not fetch when buffer is full
    reg prev_full;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            prev_full <= 1'b0;
        else
            prev_full <= prefetch_full;
    end
    
    always @(posedge clk) begin
        if (rst_n && prev_full && mem_read && !flush) begin
            $display("[ASSERTION WARNING] Fetching while buffer was full");
        end
    end
    
    // Counter for assertion tracking
    integer assertion_pass_count = 0;
    integer assertion_fail_count = 0;

endmodule
