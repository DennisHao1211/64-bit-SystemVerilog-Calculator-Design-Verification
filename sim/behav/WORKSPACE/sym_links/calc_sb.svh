class calc_sb #(int DataSize, int AddrSize);

  // Signals needed for the golden model implementation in the scoreboard
  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  //logic second_read = 0;

  bit                         got_first_read = 0;
  logic [AddrSize-1:0]        pending_addr;
  logic [DataSize-1:0]        golden_lower_l;  // A（SRAM A，低 32 位）
  logic [DataSize-1:0]        golden_upper_l;  // B（SRAM B，高 32 位）

  //int golden_lower_data;
  //int golden_upper_data;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);
      // TODO: Implement the scoreboard's core functionality.
      // The scoreboard's task is to verify the DUT's behavior by comparing the
      // data received from the monitor against a golden reference model.

      // Use the transaction flags (`initialize`, `rdn_wr`) to handle three distinct operations:
      // - For initialization, update the scoreboard's local memory (`mem_a` and `mem_b`) to match the DUT's initial SRAM state.
      // - For read operations, compare the data from the SRAM in the DUT to the dattored in the scoreboard's memory.
      //       Think about how to account for the two sequential reads in the DUT for the single write operation. The values
      //       from both read operations need to be used to compare against the calculated values in the DUT when they are written
      //       to SRAM. The second_read, golden_lower_data, and golden_upper_data signals can be used for this purpose.
      // - For write operations, compare the DUT's output to the data calculated by the golden model in the scoreboard.

      // Use `$display` to log successful transactions and `$error` to report mismatches.
      // If a mismatch occurs, use `$finish` to terminate the simulation.






      if (trans.is_init) begin
        if (trans.loc_sel == 1'b0) begin
          // 初始化 A：lower_data 有效
          mem_a[trans.curr_wr_addr] = trans.lower_data;
          $display("[%0t] SB: init A[0x%0h] = 0x%0h",
                   $time, trans.curr_wr_addr, trans.lower_data);
        end else begin
          // 初始化 B：upper_data 有效
          mem_b[trans.curr_wr_addr] = trans.upper_data;
          $display("[%0t] SB: init B[0x%0h] = 0x%0h",
                   $time, trans.curr_wr_addr, trans.upper_data);
        end
        continue;
      end

      if (trans.rdn_wr == 1'b0) begin
        if (!got_first_read) begin
          golden_lower_l = trans.lower_data;
          golden_upper_l = trans.upper_data;  
          pending_addr   = trans.curr_rd_addr;
          got_first_read = 1'b1;
        end
      
        //golden_lower_data = trans.lower_data;
        //golden_upper_data = trans.upper_data;
        //second_read       = ~second_read;
        mem_a[trans.curr_rd_addr] = trans.lower_data;
        mem_b[trans.curr_rd_addr] = trans.upper_data;
        $display("[%0t] SB: READ addr_rd=0x%0h  A=0x%0h  B=0x%0h",
                 $time, trans.curr_rd_addr, trans.lower_data, trans.upper_data);
        continue;
      end

      if (trans.rdn_wr == 1'b1) begin
        logic [DataSize-1:0] a_val, b_val, exp;

        if (got_first_read) begin
          a_val = golden_lower_l;
          b_val = golden_upper_l;
        end else begin
          a_val = mem_a[trans.curr_wr_addr][DataSize-1:0];
          b_val = mem_b[trans.curr_wr_addr][DataSize-1:0];
        end
        //a_val = mem_a[trans.curr_wr_addr][DataSize-1:0];
        //b_val = mem_b[trans.curr_wr_addr][DataSize-1:0];
        exp   = a_val + b_val;


        if (trans.loc_sel == 1'b0) begin
          if (trans.lower_data !== exp) begin
            $error("[%0t] SB: MISMATCH writing A[0x%0h]: got=0x%0h exp=0x%0h",
                   $time, trans.curr_wr_addr, trans.lower_data, exp);
            $finish(2);
          end
          mem_a[trans.curr_wr_addr] = trans.lower_data;
          $display("[%0t] SB: PASS writing A[0x%0h] = 0x%0h",
                    $time, trans.curr_wr_addr, trans.lower_data);
        end else begin
          if (trans.upper_data !== exp) begin
            $error("[%0t] SB: MISMATCH writing B[0x%0h]: got=0x%0h exp=0x%0h",
                   $time, trans.curr_wr_addr, trans.upper_data, exp);
            $finish(2);
          end
          mem_b[trans.curr_wr_addr] = trans.upper_data;
          $display("[%0t] SB: PASS writing B[0x%0h] = 0x%0h",
                    $time, trans.curr_wr_addr, trans.upper_data);
        end
        got_first_read = 0;   
        continue;
      end

      // 不应到达的分支（保护性）
      $error("[%0t] SB: Unknown transaction type", $time);
      $finish(2);

    end
  endtask

endclass : calc_sb
