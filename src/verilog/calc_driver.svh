class calc_driver #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
      mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  task reset_task();
    // Generate a short active-high reset pulse and leave reset deasserted afterwards.
    calcVif.cb.reset <= 1'b1;
    repeat (2) @(calcVif.cb);
    calcVif.cb.reset <= 1'b0;
    @(calcVif.cb);
  endtask

  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    // TODO: Write the code to drive the signals for SRAM initialization.
    //       Add a display statement to make it clearer in the simulation log that the driver is
    //       initializing the SRAM (and which one out of A or B it is)
    // HINT: Think about which signals in the clocking block should be driven to allow the
    // monitor to determine that SRAM is being initialized.
  endtask : initialize_sram

  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr, input logic [AddrSize-1:0] read_end_addr,
      input logic [AddrSize-1:0] write_start_addr, input logic [AddrSize-1:0] write_end_addr,
      input bit direct = 1);

    static bit did_reset_once = 0;
    int delay;
    calc_seq_item #(DataSize, AddrSize) trans;

    calcVif.cb.reset <= 1'b1;
    @(calcVif.cb);

    calcVif.cb.read_start_addr  <= read_start_addr;
    calcVif.cb.read_end_addr    <= read_end_addr;
    calcVif.cb.write_start_addr <= write_start_addr;
    calcVif.cb.write_end_addr   <= write_end_addr;

    repeat (2) @(calcVif.cb);

    calcVif.cb.reset <= 1'b0;

    $display("[%0t] DRIVER: start calc r[%0d:%0d] w[%0d:%0d]", $time, read_start_addr, read_end_addr, write_start_addr, write_end_addr);
    @(calcVif.cb iff calcVif.cb.ready);

    if (!direct) begin // Random Mode
      if (drv_box.try_peek(trans)) begin
        delay = $urandom_range(0, 5); // Add a Random delay before the next transaction
        repeat (delay) begin
          @(calcVif.cb);
        end
      end
    end
    calcVif.cb.reset <= 1'b0;
  endtask : start_calc

  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr, trans.read_end_addr, trans.write_start_addr, trans.write_end_addr, 0);
    end
  endtask : drive

endclass : calc_driver
