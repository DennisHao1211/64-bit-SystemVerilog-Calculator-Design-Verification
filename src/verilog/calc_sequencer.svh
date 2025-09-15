class calc_sequencer #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) calc_box;

  function new();
    calc_box = new();
  endfunction : new

  task gen (int num);
    repeat (num) begin
      calc_seq_item #(DataSize, AddrSize) my_trans = new();
      if (!my_trans.randomize()) $error;
      calc_box.put(my_trans);
    end
  endtask : gen

endclass : calc_sequencer
