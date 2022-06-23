class ahb_sagent extends uvm_component;

  // ahb_drv drv;
  ahb_responder responder;
  ahb_mon mon;
  
  `uvm_component_utils(ahb_sagent)
  `NEW_COMPONENT
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    responder = ahb_responder::type_id::create("responder", this);
    //mon = ahb_mon::type_id:;create("mon", this); //two monitors lead to two prints so commenting now for easier debug, previously we had two writes and reads, one through master interface and other through slave interface
  endfunction
  
endclass