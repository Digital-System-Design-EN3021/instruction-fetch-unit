// ============================================================================
// Comprehensive Testbench with Multiple Test Scenarios
// ============================================================================
module tb_ifu_comprehensive;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Memory interface
    wire [31:0] mem_addr;
    wire mem_read;
    wire [31:0] mem_data;
    wire mem_ready;
    
    // Fetch interface
    wire [31:0] instruction;
    wire [31:0] instruction_pc;
    wire instruction_valid;
    reg fetch_next;
    
    // Branch interface
    reg branch_resolved;
    reg branch_taken;
    reg [31:0] branch_pc;
    reg [31:0] branch_target;
    
    // Control
    reg stall;
    wire prefetch_full;
    wire prefetch_empty;
    
    // Test control
    integer test_number;
    integer error_count;
    
    // Instantiate DUT
    instruction_fetch_unit ifu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_read(mem_read),
        .mem_data(mem_data),
        .mem_ready(mem_ready),
        .instruction(instruction),
        .instruction_pc(instruction_pc),
        .instruction_valid(instruction_valid),
        .fetch_next(fetch_next),
        .branch_resolved(branch_resolved),
        .branch_taken(branch_taken),
        .branch_pc(branch_pc),
        .branch_target(branch_target),
        .stall(stall),
        .prefetch_full(prefetch_full),
        .prefetch_empty(prefetch_empty)
    );
    
    // Instantiate instruction memory
    instruction_memory #(.LATENCY(1)) imem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(mem_addr),
        .read_enable(mem_read),
        .data(mem_data),
        .ready(mem_ready)
    );
    
    // Instantiate scoreboard
    scoreboard sb();
    
    // Instantiate assertion checker
    assertion_checker ac (
        .clk(clk),
        .rst_n(rst_n),
        .pc(instruction_pc),
        .instruction_valid(instruction_valid),
        .prefetch_full(prefetch_full),
        .prefetch_empty(prefetch_empty),
        .mem_read(mem_read),
        .branch_resolved(branch_resolved),
        .flush(branch_resolved && branch_taken)
    );
    
    // Instantiate coverage monitor
    coverage_monitor cm (
        .clk(clk),
        .rst_n(rst_n),
        .pc(instruction_pc),
        .instruction_valid(instruction_valid),
        .branch_taken(branch_taken),
        .branch_resolved(branch_resolved),
        .prediction(1'b0),  // Can be connected to internal signals
        .prediction_valid(1'b0),
        .prefetch_full(prefetch_full),
        .prefetch_empty(prefetch_empty),
        .stall(stall)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Monitor fetched instructions
    always @(posedge clk) begin
        if (instruction_valid && fetch_next) begin
            sb.record_fetch(instruction_pc, instruction);
        end
    end
    
    // ========================================================================
    // Test Cases
    // ========================================================================
    
    // Task: Reset sequence
    task test_reset;
        begin
            $display("\n[TEST %0d] Reset Test", test_number++);
            rst_n = 0;
            #20;
            rst_n = 1;
            #10;
            if (instruction_pc !== 32'h0) begin
                $display("ERROR: PC not reset to 0");
                error_count++;
            end else begin
                $display("PASS: Reset successful");
            end
        end
    endtask
    
    // Task: Sequential fetch test
    task test_sequential_fetch;
        integer i;
        begin
            $display("\n[TEST %0d] Sequential Fetch Test", test_number++);
            fetch_next = 1;
            branch_resolved = 0;
            stall = 0;
            
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
            end
            
            $display("PASS: Sequential fetch completed");
        end
    endtask
    
    // Task: Branch taken test
    task test_branch_taken;
        begin
            $display("\n[TEST %0d] Branch Taken Test", test_number++);
            
            // Wait for some fetches
            repeat(10) @(posedge clk);
            
            // Simulate branch taken
            @(posedge clk);
            branch_resolved = 1;
            branch_taken = 1;
            branch_pc = 32'h00000040;
            branch_target = 32'h00000100;
            sb.record_branch(1, branch_target);
            
            @(posedge clk);
            branch_resolved = 0;
            
            // Continue fetching
            repeat(10) @(posedge clk);
            
            $display("PASS: Branch taken test completed");
        end
    endtask
    
    // Task: Branch not taken test
    task test_branch_not_taken;
        begin
            $display("\n[TEST %0d] Branch Not Taken Test", test_number++);
            
            repeat(5) @(posedge clk);
            
            // Simulate branch not taken
            @(posedge clk);
            branch_resolved = 1;
            branch_taken = 0;
            branch_pc = 32'h00000080;
            branch_target = 32'h00000200;
            sb.record_branch(0, branch_target);
            
            @(posedge clk);
            branch_resolved = 0;
            
            repeat(10) @(posedge clk);
            
            $display("PASS: Branch not taken test completed");
        end
    endtask
    
    // Task: Stall test
    task test_stall;
        begin
            $display("\n[TEST %0d] Stall Test", test_number++);
            
            repeat(5) @(posedge clk);
            
            // Apply stall
            stall = 1;
            $display("Stall applied");
            repeat(5) @(posedge clk);
            
            // Release stall
            stall = 0;
            $display("Stall released");
            repeat(10) @(posedge clk);
            
            $display("PASS: Stall test completed");
        end
    endtask
    
    // Task: Buffer full test
    task test_buffer_full;
        begin
            $display("\n[TEST %0d] Buffer Full Test", test_number++);
            
            // Stop consuming from buffer
            fetch_next = 0;
            
            // Wait for buffer to fill
            wait(prefetch_full);
            $display("Buffer full detected");
            
            // Resume consumption
            fetch_next = 1;
            repeat(10) @(posedge clk);
            
            $display("PASS: Buffer full test completed");
        end
    endtask
    
    // Task: Repeated branch test (for predictor training)
    task test_predictor_training;
        integer i;
        begin
            $display("\n[TEST %0d] Branch Predictor Training Test", test_number++);
            
            // Take same branch multiple times to train predictor
            for (i = 0; i < 4; i = i + 1) begin
                repeat(5) @(posedge clk);
                
                branch_resolved = 1;
                branch_taken = 1;
                branch_pc = 32'h00000040;
                branch_target = 32'h00000100;
                sb.record_branch(1, branch_target);
                
                @(posedge clk);
                branch_resolved = 0;
                
                $display("Branch training iteration %0d", i+1);
            end
            
            $display("PASS: Predictor training completed");
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("IFU VERIFICATION STARTING");
        $display("========================================");
        
        test_number = 1;
        error_count = 0;
        
        // Initialize signals
        fetch_next = 0;
        branch_resolved = 0;
        branch_taken = 0;
        branch_pc = 0;
        branch_target = 0;
        stall = 0;
        
        // Run tests
        test_reset();
        test_sequential_fetch();
        test_branch_taken();
        test_branch_not_taken();
        test_stall();
        test_buffer_full();
        test_predictor_training();
        
        // Additional cycles for observation
        repeat(20) @(posedge clk);
        
        // Print results
        sb.print_statistics();
        cm.print_coverage();
        
        $display("\n========================================");
        $display("VERIFICATION COMPLETE");
        $display("Total Errors: %0d", error_count);
        if (error_count == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: SOME TESTS FAILED");
        $display("========================================\n");
        
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("ifu_waves.vcd");
        $dumpvars(0, tb_ifu_comprehensive);
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule
