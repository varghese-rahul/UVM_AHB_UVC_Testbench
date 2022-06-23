//define a test
class ahb_base_test extends uvm_test;
  ahb_env env;
  `uvm_component_utils(ahb_base_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    // super.build_phase(phase);
    `uvm_info("AHB_UVC", "Test: Build_phase", UVM_NONE)
    env = ahb_env::type_id::create("env", this);
    uvm_config_db#(int)::set(this, "env.magent.*", "master_slave_f", 1);
    uvm_config_db#(int)::set(this, "env.sagent.*", "master_slave_f", 0);
  endfunction
  
  function void end_of_elaboration_phase(uvm_phase phase);
    // super.end_of_elaboration_phase(phase);
    `uvm_info("TB HIERARCHY", this.sprint(), UVM_NONE)
  endfunction
  
  function void report_phase(uvm_phase phase);
    if ((ahb_common::total_tx == ahb_common::num_matches) && abh_common::num_mismatches == 0) begin
      `uvm_info("STATUS", "Test is passing", UVM_NONE)
    end
    else begin
      `uvm_error("STATUS", "Test is failing")
    end
  endfunction
  
  
endclass

class ahb_wr_rd_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  
  task run_phase(uvm_phase phase);
    ahb_wr_rd_seq wr_rd_seq;
    wr_rd_seq = ahb_wr_rd_seq::type_id::create("wr_rd_sq");
    phase.phase_done.set_drain_time(this, 100);
    phase.raise_objection(this);
    wr_rd_seq.start(env.magent.sqr);
    phase.drop_objection(this);
  endtask
  
endclass

//DEFAULT SEQUENCE E.G.
class ahb_wr_rd_build_phase_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_build_phase_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_wr_rd_seq::get_type());
  endfunction
  
endclass

class ahb_mult_wr_rd_test extends ahb_base_test;
  `uvm_component_utils(ahb_mult_wr_rd_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_resource_db#(int)::set("GLOBAL", "NUM_TX", 5);
    ahb_common::total_tx = 10;
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_mult_wr_rd_seq::get_type());
  endfunction
  
endclass

class ahb_wr_rd_wrap_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_wrap_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_wr_rd_wrap_seq::get_type());
  endfunction
  
endclass

class ahb_mult_wr_rd_wrap_test extends ahb_base_test;
  `uvm_component_utils(ahb_mult_wr_rd_wrap_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_resource_db#(int)::set("GLOBAL", "NUM_TX", 5);
    ahb_common::total_tx = 10; //this value is going to be double of the above because of both master and slave monitors
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_mult_wr_rd_wrap_seq::get_type());
  endfunction
  
endclass

class ahb_wr_rd_incr8_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_incr8_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_wr_rd_incr8_seq::get_type());
  endfunction
  
endclass

class ahb_wr_rd_incr16_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_incr16_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_wr_rd_incr16_seq::get_type());
  endfunction
  
endclass

class ahb_wr_rd_wrap16_test extends ahb_base_test;
  `uvm_component_utils(ahb_wr_rd_wrap16_test)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", ahb_wr_rd_wrap16_seq::get_type());
  endfunction
  
endclass