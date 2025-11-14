module calc_tb_top;

  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 0;
  logic rst;
  state_t state;
  logic [DataSize-1:0] rd_data;
  bit quiet_ok;

  typedef logic [AddrSize-1:0] addr_t;

  // Directed task: Boundary conditions
  localparam addr_t ADDR_MAX    = {AddrSize{1'b1}};
  localparam addr_t ADDR_MAX_M1 = ADDR_MAX - addr_t'(1);

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    `ifdef VCS
    .read_start_addr(calc_if.read_start_addr),
    .read_end_addr(calc_if.read_end_addr),
    .write_start_addr(calc_if.write_start_addr),
    .write_end_addr(calc_if.write_end_addr),
    .loc_sel(calc_if.loc_sel)
    `endif
    `ifdef CADENCE
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr),
    .loc_sel(calc_if.calc.loc_sel)
    `endif
  );

  assign rst = calc_if.reset;
  assign state = calculator_pkg::state_t'(my_calc.u_ctrl.state);

  `ifdef VCS
  assign calc_if.rd_en         = my_calc.read_ctrl;
  assign calc_if.curr_rd_addr  = my_calc.r_addr_ctrl;
  assign calc_if.rd_data       = my_calc.r_data_ctrl;

  assign calc_if.wr_en         = (my_calc.write_a | my_calc.write_b);
  assign calc_if.curr_wr_addr  = (my_calc.buffer_control_ctrl) ? my_calc.w_addr_b : my_calc.w_addr_a;
  assign calc_if.wr_data       = my_calc.buffer_result;

  assign calc_if.ready = (state == calculator_pkg::S_END);
  `endif
  `ifdef CADENCE

  assign calc_if.calc.rd_en         = my_calc.read_ctrl;
  assign calc_if.calc.curr_rd_addr  = my_calc.r_addr_ctrl;
  assign calc_if.calc.rd_data       = my_calc.r_data_ctrl;

  assign calc_if.calc.wr_en         = (my_calc.write_a | my_calc.write_b);
  assign calc_if.calc.curr_wr_addr  = (my_calc.buffer_control_ctrl) ? my_calc.w_addr_b : my_calc.w_addr_a;
  assign calc_if.calc.wr_data       = my_calc.buffer_result;

  assign calc_if.calc.ready         = (state == calculator_pkg::S_END);

  `endif

  calc_tb_pkg::calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
  calc_tb_pkg::calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
  calc_tb_pkg::calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) begin
      my_calc.sram_A.mem[addr] = data;
    end
    else begin
      my_calc.sram_B.mem[addr] = data;
    end
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask

  // Coverage of the Condition
  task automatic start_and_wait(addr_t rs, addr_t re, addr_t ws, addr_t we);
    calc_driver_h.start_calc(rs, re, ws, we, 1'b1);
  `ifdef VCS
    wait (calc_if.ready);
  `else
    wait (calc_if.calc.ready);
  `endif
    repeat (2) @(posedge clk);
  endtask


task automatic wait_ready();
`ifdef VCS
  wait (calc_if.ready);
`else
  wait (calc_if.calc.ready);
`endif
  repeat (2) @(posedge clk);
endtask


task automatic drive_invalid_window(
  addr_t rs, addr_t re, addr_t ws, addr_t we
);
`ifdef VCS
  calc_if.read_start_addr  <= rs;
  calc_if.read_end_addr    <= re;
  calc_if.write_start_addr <= ws;
  calc_if.write_end_addr   <= we;
  repeat (1) @(posedge clk);
  calc_if.reset <= 1;
  repeat (1) @(posedge clk);
  calc_if.reset <= 0;
`else
  calc_if.calc.read_start_addr  <= rs;
  calc_if.calc.read_end_addr    <= re;
  calc_if.calc.write_start_addr <= ws;
  calc_if.calc.write_end_addr   <= we;
  repeat (1) @(posedge clk);
  calc_if.calc.reset <= 1;
  repeat (1) @(posedge clk);
  calc_if.calc.reset <= 0;
`endif
  repeat (3) @(posedge clk);
endtask


  initial begin
    `ifdef VCS
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, calc_tb_top, "+mda", "+all", "+trace_process");
    $fsdbDumpMDA;
    `endif
    `ifdef CADENCE
    $shm_open("waves.shm");
    $shm_probe("AC");
    `endif

    calc_monitor_h = new(calc_if);
    calc_sb_h = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none

    
    calc_if.reset <= 1;
    for (int i = 0; i < 2 ** AddrSize; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

 
    `ifdef VCS
    calc_if.reset <= 0;
    `else
    calc_if.calc.reset <= 0;
    `endif
    repeat (2) @(posedge clk);

    // Directed part

    // Test case 1 - normal addition
    $display("Test case 1 - normal addition");
    // TODO: Finish test case 1
    $display("Test case 1 - normal addition (7 + 9 -> 16)");
    calc_driver_h.reset_task();
    write_sram(8'h10, 32'd7, 1'b0);
    write_sram(8'h10, 32'd9, 1'b1);
    write_sram(8'h11, 32'd0, 1'b0);
    write_sram(8'h11, 32'd0, 1'b1);
    calc_driver_h.start_calc(8'h10, 8'h11, 8'h10, 8'h10, 1'b1);
    `ifdef VCS
    wait (calc_if.ready == 1'b1);
    `else
    wait (calc_if.calc.ready == 1'b1);
    `endif
    repeat (5) @(posedge clk);
  
    // Test case 2 - addition with overflow
    $display("Test case 2 - addition with overflow");
    calc_driver_h.reset_task();
    write_sram(8'h20, 32'hFFFF_FFFF, 1'b0); 
    write_sram(8'h20, 32'h0000_0001, 1'b1); 
    write_sram(8'h21, '0, 1'b0);
    write_sram(8'h21, '0, 1'b1);
    calc_driver_h.start_calc(8'h20, 8'h21, 8'h20, 8'h20, 1'b1);
    `ifdef VCS
    wait (calc_if.ready == 1'b1);
    `else
    wait (calc_if.calc.ready == 1'b1);
    `endif
    repeat (5) @(posedge clk);
    // TODO: Finish test case 1

    // TODO: Add test cases according to your test plan. If you need additional test cases to reach
    // 96% coverage, make sure to add them to your test plan



// Edge Cases (directed)
$display("Edge Cases — Zero+Zero / Max+Max / Zero+Max");

// Zero + Zero => 0 
calc_driver_h.reset_task();
write_sram(8'h30, 32'h0000_0000, 1'b0); 
write_sram(8'h30, 32'h0000_0000, 1'b1); 
write_sram(8'h31, 32'h0000_0000, 1'b0); 
write_sram(8'h31, 32'h0000_0000, 1'b1); 
calc_driver_h.start_calc(8'h30, 8'h31, 8'h30, 8'h30, 1'b1);
`ifdef VCS
  wait (calc_if.ready == 1'b1);
`else
  wait (calc_if.calc.ready == 1'b1);
`endif
repeat (3) @(posedge clk);

// Max + Max 
calc_driver_h.reset_task();
write_sram(8'h40, 32'hFFFF_FFFF, 1'b0); 
write_sram(8'h40, 32'hFFFF_FFFF, 1'b1); 
write_sram(8'h41, 32'h0000_0000, 1'b0); 
write_sram(8'h41, 32'h0000_0000, 1'b1);
calc_driver_h.start_calc(8'h40, 8'h41, 8'h40, 8'h40, 1'b1);
`ifdef VCS
  wait (calc_if.ready == 1'b1);
`else
  wait (calc_if.calc.ready == 1'b1);
`endif
repeat (3) @(posedge clk);

// Zero + Max => 0xFFFF_FFFF 
calc_driver_h.reset_task();
write_sram(8'h50, 32'h0000_0000, 1'b0); 
write_sram(8'h50, 32'hFFFF_FFFF, 1'b1); 
write_sram(8'h51, 32'h0000_0000, 1'b0); 
write_sram(8'h51, 32'h0000_0000, 1'b1);
calc_driver_h.start_calc(8'h50, 8'h51, 8'h50, 8'h50, 1'b1);
`ifdef VCS
  wait (calc_if.ready == 1'b1);
`else
  wait (calc_if.calc.ready == 1'b1);
`endif
repeat (3) @(posedge clk);


// Directed tests for read_start_addr coverage (bit flips + boundary)
// All address bits are exercised in simulation
$display("Directed coverage for read_start_addr");
start_and_wait(8'h01, 8'h02, 8'h10, 8'h11); // bit0
start_and_wait(8'h02, 8'h03, 8'h12, 8'h13); // bit1
start_and_wait(8'h04, 8'h05, 8'h14, 8'h15); // bit2
start_and_wait(8'h08, 8'h09, 8'h18, 8'h19); // bit3
start_and_wait(8'h80, 8'h81, 8'h20, 8'h21); // MSB

// Boundary conditions
start_and_wait(8'h00, 8'h01, 8'h30, 8'h31); // lowest window
start_and_wait(ADDR_MAX_M1, ADDR_MAX, 8'h40, 8'h41); // highest window

wait_ready();

// Coverage of the Condition
// READ invalid, WRITE valid  覆盖 (read_invalid=1, write_invalid=0)
$display("Directed: invalid READ window (rs > re)");
drive_invalid_window(addr_t'(8'h22), addr_t'(8'h21), addr_t'(8'h10), addr_t'(8'h11));
assert (state == calculator_pkg::S_IDLE)
  else $error("Not IDLE on invalid READ");
`ifdef VCS
  assert (!calc_if.rd_en && !calc_if.wr_en);
`else
  assert (!calc_if.calc.rd_en && !calc_if.calc.wr_en);
`endif

// READ valid, WRITE invalid -> 覆盖 (0,1)
$display("Directed: invalid WRITE window (ws > we)");
drive_invalid_window(addr_t'(8'h10), addr_t'(8'h11), addr_t'(8'h33), addr_t'(8'h32));
assert (state == calculator_pkg::S_IDLE)
  else $error("Not IDLE on invalid WRITE");
`ifdef VCS
  assert (!calc_if.rd_en && !calc_if.wr_en);
`else
  assert (!calc_if.calc.rd_en && !calc_if.calc.wr_en);
`endif

// READ invalid, WRITE invalid -> 覆盖 (1,1)
$display("Directed: both READ & WRITE invalid");
drive_invalid_window(addr_t'(8'h25), addr_t'(8'h24), addr_t'(8'h44), addr_t'(8'h43));
assert (state == calculator_pkg::S_IDLE)
  else $error("Not IDLE on both invalid");
`ifdef VCS
  assert (!calc_if.rd_en && !calc_if.wr_en);
`else
  assert (!calc_if.calc.rd_en && !calc_if.calc.wr_en);
`endif


    // Random part
    $display("Randomized Testing");
    // TODO: Finish randomized testing
    // HINT: The sequencer is responsible for generating random input sequences. How can the
    // sequencer and driver be combined to generate multiple randomized test cases?
    calc_sequencer_h.gen(100, 8'h00, 8'hFE);
    calc_driver_h.drive();
    repeat (100) @(posedge clk);


// Reset during FSM states 
$display("Reset during READ1");
fork
  KICKOFF(); // calc_driver_h.start_calc(8'h04, 8'h07, 8'h64, 8'h67, 1'b1);       
  RESET_IN_READ1();
join_any
disable fork;
assert_idle_and_stabilize();

$display("Reset during ADD1");
fork
  KICKOFF();
  RESET_IN_ADD1();
join_any
disable fork;
assert_idle_and_stabilize();

$display("Reset during READ2");
fork
  KICKOFF();
  RESET_IN_READ2();
join_any
disable fork;
assert_idle_and_stabilize();

$display("Reset during ADD2");
fork
  KICKOFF();
  RESET_IN_ADD2();
join_any
disable fork;
assert_idle_and_stabilize();

$display("Reset during WRITE");
fork
  KICKOFF();
  RESET_IN_WRITE();
join_any
disable fork;
assert_idle_and_stabilize();

  $display("TEST PASSED");



    $finish;
  end

  /********************
        ASSERTIONS
  *********************/

  // TODO: Add Assertions



// RESET:
property p_no_en_during_reset_grace;
  @(posedge clk)
    $rose(calc_if.reset) |-> ##1
      ((!calc_if.wr_en && !calc_if.rd_en) throughout calc_if.reset);
endproperty
a_no_en_during_reset: assert property (p_no_en_during_reset_grace)
  else $error("ASSERT NO_EN_DURING_RESET failed at %0t", $time);

// VALID_INPUT_ADDRESS：
property p_rd_addr_in_window;
  @(posedge clk) disable iff (calc_if.reset)
    calc_if.rd_en |-> (calc_if.curr_rd_addr >= calc_if.read_start_addr) && (calc_if.curr_rd_addr <= (calc_if.read_end_addr + 1));
endproperty
a_rd_addr_in_window: assert property (p_rd_addr_in_window)
  else $error("ASSERT RD_ADDR_WINDOW failed at %0t: rd_addr=0x%0h win=[0x%0h:0x%0h(+1)]", $time, calc_if.curr_rd_addr, calc_if.read_start_addr, calc_if.read_end_addr);

// BUFFER_LOC_TOGGLES/LSBs before MSBs：
cover property (@(posedge clk) my_calc.buffer_we_ctrl && my_calc.buffer_control_ctrl);
property p_lsb_before_msb_same_addr;
  logic [AddrSize-1:0] addr;
  @(posedge clk) disable iff (calc_if.reset)
    (my_calc.buffer_we_ctrl && !my_calc.buffer_control_ctrl, addr = calc_if.curr_wr_addr)
      |-> ##[1:3]
          (my_calc.buffer_we_ctrl && my_calc.buffer_control_ctrl && calc_if.curr_wr_addr == addr);
endproperty
a_lsb_before_msb_same_addr: assert property (p_lsb_before_msb_same_addr)
  else $error("ASSERT LSB_BEFORE_MSB failed at %0t: addr=0x%0h", $time, calc_if.curr_wr_addr);

  // Verify FSM recovery: after a reset in any state, the FSM should go back to S_IDLE
  task automatic reset_in_state(calculator_pkg::state_t target, int cycles = 5);
    wait (state == target);
    calc_if.reset <= 1;
    repeat (cycles) @(posedge clk);
    calc_if.reset <= 0;
  endtask

  task automatic RESET_IN_READ1(); reset_in_state(calculator_pkg::S_READ1); endtask
  task automatic RESET_IN_ADD1 (); reset_in_state(calculator_pkg::S_ADD1 ); endtask
  task automatic RESET_IN_READ2(); reset_in_state(calculator_pkg::S_READ2); endtask
  task automatic RESET_IN_ADD2 (); reset_in_state(calculator_pkg::S_ADD2 ); endtask
  task automatic RESET_IN_WRITE(); reset_in_state(calculator_pkg::S_WRITE); endtask

  // 调用KICKOFF()
  task automatic KICKOFF();
    calc_driver_h.start_calc(8'h04, 8'h07, 8'h64, 8'h67, 1'b1);
  endtask

  // Reset during FSM states: Check that the FSM returns to the S_IDLE state after reset
  task automatic assert_idle_and_stabilize();
    assert (state == calculator_pkg::S_IDLE)
      else $error("[%0t] FSM did not return to IDLE after reset, state=%0d", $time, state);
    repeat (2) @(posedge clk);
  endtask
  
endmodule 