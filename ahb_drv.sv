class ahb_drv extends uvm_driver#(ahb_tx);
  // bit master_slave_f;
  virtual ahb_intf.master_mp vif;
  virtual arb_intf.master_mp arb_vif;
  `uvm_component_utils_begin(ahb_drv)
  	//`uvm_field_int(master_slave_f, UVM_ALL_ON)
  `uvm_component_utils_end
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_resource_db#(virtual ahb_intf)::read_by_type("AHB", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve ahb_vif handle from resource_db")
    end
    if(!uvm_resource_db#(virtual arb_intf)::read_by_type("AHB", arb_vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve arb_vif handle from resource_db")
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    // if(master_slave_f == 1) begin
    wait (vif.master_cb.hrst == 0); //wait for reset to be released, before starting the driver functionality 
    forever begin
      seq_item_port.get_next_item(req);
      //req.print(); //method to print from driver
      drive_tx(req); //drive the AHB interface with the request
      seq_item_port.item_done();//I am done with this item
    end
    // end
    /* else begin
      `uvm_info("AHB_DRIVER", "Driver behaving like slave", UVM_NONE)
    end */
  endtask
  
  task drive_tx(ahb_tx req);
    arb_phase(req); //to get grant to interconnect
    //implement burst_len number of phases
    //also implement pipelining
    addr_phase(req, 1);
    //#10;
    for (int i = 0; i < req.len-1; i = i+1) begin
      fork
        //#10;
        addr_phase(req);
        data_phase(req);
      join
    end
   data_phase(req);
   set_default_values();
  endtask
  
  task set_default_values();
   arb_vif.master_cb.hbusreq <= 0; //make 0 so that the 1 doesn't persist for whole simulation time
   arb_vif.master_cb.hlock <= 0;
   vif.master_cb.haddr <= 0;
   vif.master_cb.hburst <= 0;
   vif.master_cb.hprot <= 0;
   vif.master_cb.hsize <= 0;
   vif.master_cb.hnonsec <= 0;
   vif.master_cb.hexcl <= 0;
   vif.master_cb.htrans <= IDLE;
   vif.master_cb.hwrite <= 0;
   @(vif.master_cb);
   vif.master_cb.hwdata <= 0; 
  endtask
  
  task arb_phase(ahb_tx req);
    `uvm_info("AHB_TX", "arb_phase", UVM_FULL)
    //signals required for arbitration phase
    @(arb_vif.master_cb);
    arb_vif.master_cb.hbusreq[req.master] <= 1; //req.master indicates which master is making request, corresponding hbusreq is driven to 1
    arb_vif.master_cb.hlock[req.master] <= req.mastlock;
    wait (arb_vif.master_cb.hgrant[req.master] == 1);
    arb_vif.master_cb.hmaster <= req.master;
    arb_vif.master_cb.hmastlock <= req.mastlock;
    // @(arb_vif.master_cb);
  endtask
  
  task addr_phase(ahb_tx req=null, bit first_beat_f = 0);
    `uvm_info("AHB_TX", "addr_phase", UVM_FULL)
    @(vif.master_cb);
    vif.master_cb.haddr <= req.addr_t;
    vif.master_cb.hburst <= req.burst;
    vif.master_cb.hprot <= req.prot;
    vif.master_cb.hsize <= req.size;
    vif.master_cb.hnonsec <= req.nonsec;
    vif.master_cb.hexcl <= req.excl;
    if(first_beat_f == 1) vif.master_cb.htrans <= NONSEQ;
    if(first_beat_f == 0) vif.master_cb.htrans <= SEQ;
    vif.master_cb.hwrite <= req.wr_rd;
    // wait (vif.master_cb.hreadyout == 1); //hready not transaction signal so no ready exists
    // do not wait for hready in 1st beat
    req.addr_t = req.addr_t + 2**req.size;
    /*if (req.burst inside {WRAP4, WRAP8, WRAP16}) begin
      	if (req.addr_t > req.upper_wrap_addr) req.addr_t = req.lower_wrap_addr; //this line is added to support the WRAP feature
    end */
    if (first_beat_f == 0) wait (vif.master_cb.hreadyout == 1);
  endtask
  
  task data_phase(ahb_tx req);
    `uvm_info("AHB_TX", "data_phase", UVM_FULL)
     @(vif.master_cb);
    if (req.wr_rd == 1) vif.master_cb.hwdata <= req.dataQ.pop_front();
    if (req.wr_rd == 0) req.dataQ.push_back(vif.master_cb.hrdata);
    req.resp = vif.master_cb.hresp;
    if (vif.master_cb.hresp == ERROR) begin
      `uvm_error("AHB_TX", "Slave issued error response")
    end
    `uvm_info("AHB_TX", $psprintf("Driving data=%h at addr=%d", vif.master_cb.hwdata, req.addr_t), UVM_FULL)
    wait (vif.master_cb.hreadyout == 1);
  endtask
  
endclass


/*It is ahb_driver's responsiblity to figure out when the upper boundary of wrap has reached, at that time wrap back to lower boundary. ahb_driver should know the wrap boundaries, so that it knows when to wrap back. There are 2 options:
	. do all the calculations in the ahb_driver.sv
	. do all the calculations in ahb_tx.sv which is the preferred option.
		. anything related to ahb_tx fields should be kept in ahb_tx.sv only (not other files)
If the design is working like a master (e.g. processor), then we don't do the above calculations because processor will take care of it. The VIP will be Slave UVC.

Ahb_intf for transaction related signals and arb_int for arbitration phase related signals.

Generally, interconnect internally has arbiter which gives grant, but for current scenario, we treat slave as a special case and implement arbitration on grant to the slave.

To avoid x in signal values, reset them in top.sv to a default state.

We need to wait for reset phase to finish before driving. Also, we need to wait another posedge clk before resetting (not needed).

We implemented addr_t to be able to write and read from same place but how does it work?