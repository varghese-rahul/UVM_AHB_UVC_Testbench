class ahb_cov extends uvm_subscriber#(ahb_tx);
  ahb_tx tx;
  event ahb_e;
  `uvm_component_utils(ahb_cov)
  
  covergroup ahb_cg@(ahb_e);
    WR_RD_CP : coverpoint tx.wr_rd;
    BURST_CP : coverpoint tx.burst;
    SIZE_CP : coverpoint tx.size;
  endgroup
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ahb_cg = new(); // don't use `NEW_COMP unless you do this in build_phase
  endfunction
  
  virtual function void write(T t); //originally a pure function that needs to be implemented when extended/inherited from
    $cast(tx, t);
    ahb_cg.sample();
  endfunction
  
endclass

/*Monitor didn't collect read so there is no coverage for that as expected
Only focused on a specific size and burst so there is less coverage for that as expected
If you want to increase coverage for size and burst, pass a hard constraint using sequence inline constraint 