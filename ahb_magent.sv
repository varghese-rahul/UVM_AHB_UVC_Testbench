class ahb_magent extends uvm_component;
  // bit master_slave_f;
  ahb_sqr sqr;
  ahb_drv drv;
  ahb_mon mon;
  ahb_cov cov;
  
  `uvm_component_utils_begin(ahb_magent)
  //	`uvm_field_int(master_slave_f, UVM_ALL_ON)
  `uvm_component_utils_end
  `NEW_COMPONENT
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = ahb_sqr::type_id::create("sqr", this);
    drv = ahb_drv::type_id::create("drv", this);
    mon = ahb_mon::type_id:;create("mon", this);
    cov = ahb_cov::type_id::create("cov", this);
  endfunction
  
  function void connect_phase(uvm_phase);
    super.connect_phase(phase);
    drv.item_get_port.(sqr.item_get_export);
    mon.ap_port.connect(cov.analysis_export);
  endfunction
  
endclass

//uvm_subscriber has analysis_export by default unlike analysis_port for uvm_monitor