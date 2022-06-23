class ahb_responder extends uvm_driver#(ahb_tx);
  // bit master_slave_f;
  virtual ahb_intf.slave_mp vif;
  virtual ahb_intf vif_nocb;
  virtual arb_intf.slave_mp arb_vif;
  //Slave is essentially a memory with AHB interface
  byte mem[*]; //associative array
  //dynamic array: memory of 2**32 locations, address width is 32 bits
  //fixed size array : byte mem[107341823:0]; //laptop/simulation will hang and is inefficient
  
  //temporary variables to memorize previous transaction address phase information
  bit [31:0] addr_t;
  bit [2:0] burst_t;
  bit [6:0] prot_t;
  bit [2:0] size_t;
  bit nonsec_t;
  bit excl_t;
  bit [1:0] prev_htrans;
  bit write_t;
  
  `uvm_component_utils_begin(ahb_responder)
  	//`uvm_field_int(master_slave_f, UVM_ALL_ON)
  `uvm_component_utils_end
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_resource_db#(virtual ahb_intf)::read_by_type("AHB", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve ahb_vif handle from resource_db")
    end
    if(!uvm_resource_db#(virtual ahb_intf)::read_by_type("AHB", vif_nocb, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve ahb_vif handle from resource_db")
    end
    if(!uvm_resource_db#(virtual arb_intf)::read_by_type("AHB", arb_vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve arb_vif handle from resource_db")
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    //respond to the requests coming from master driver
    fork
    //Arbitration grant
    forever begin
      @(arb_vif.slave_cb);
      arb_vif.slave_cb.hgrant <= 0; //makes sure by default grant is 0
      if(arb_vif.slave_cb.hbusreq[0] == 1) begin
        arb_vif.slave_cb.hgrant[0] <= 1;
      end
      else if (arb_vif.slave_cb.hbusreq[1] == 1) begin
        arb_vif.slave_cb.hgrant[1] <= 1;
      end
      //so on till 15
    end
    //Handling AHB write/read requests
    forever begin
      //@(vif.slave_cb);
      @(posedge vif_nocb.hclk);
      vif_nocb.hreadyout = 0;
      //case (vif.slave_cb.htrans) //current_htrans
      //$display("%t: prev_htrans = %b, current_htrans = %b", $time, prev_htrans, vif_nocb.htrans);
      case (vif_nocb.htrans) //current_htrans
        IDLE : begin
          case (prev_htrans)
            IDLE : begin
              //Do nothing: both address and data phases are invalid
              idle_phase();
            end
            BUSY : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_BUSY_IDLE")
            end
            NONSEQ, SEQ : begin
              //no address phase sice current trans is IDLE
              data_phase(); //If write is happening, store data in to memory, if read is happening, provide the data
              vif_nocb.hreadyout=1;
            end
          endcase
        end
        BUSY : begin
          case (prev_htrans)
            IDLE : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_IDLE_BUSY")
            end
            BUSY : begin
              //Do nothing
            end
            NONSEQ, SEQ : begin
              data_phase();
              vif_nocb.hreadyout=1;
            end
          endcase
        end
        NONSEQ : begin
          case (prev_htrans)
            IDLE : begin
              $display("%t: Calling collect_addr_phase", $time);
              collect_addr_phase();
              vif_nocb.hreadyout=1;
            end
            BUSY : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_BUSY_NONSEQ")
            end
            NONSEQ, SEQ : begin
              data_phase();
              collect_addr_phase();
              vif_nocb.hreadyout=1;
            end
          endcase
        end
        SEQ : begin
          case (prev_htrans)
            IDLE : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_IDLE_SEQ")
            end
            BUSY : begin
              collect_addr_phase();
              vif_nocb.hreadyout=1;
            end
            NONSEQ, SEQ : begin
              data_phase();
              collect_addr_phase();
              vif_nocb.hreadyout=1;
            end
          endcase
        end
      endcase
      
      prev_htrans = vif.slave_cb.htrans;
      
      /*if (vif.slave_cb.htrans inside {NONSEQ, SEQ}) begin
        vif.slave_cb.hreadyout <= 1;
      end
      else begin
        vif.slave_cb.hreadyout <= 0;
      end*/
    end
    join
  endtask
  
  //AHB works on pipelining nature, current cycle addr, burst, prot, size etc will be used in next clock cycle data transfer
  task collect_addr_phase();
    addr_t = vif_nocb.haddr;
    burst_t = vif_nocb.hburst;
    prot_t = vif_nocb.hprot;
    size_t = vif_nocb.hsize;
    nonsec_t = vif_nocb.hnonsec;
    excl_t = vif_nocb.hexcl;
    prev_htrans = vif_nocb.htrans;
    write_t = vif_nocb.hwrite;
    data_phase();
  endtask
  
  //you write to memory if it's a write otherwise read from memory
  //the implemented data phase is incomplete as you need to use signals from address phase
  task data_phase();
    bit [63:0] wdata_t, rdata_t;
      wdata_t = vif_nocb.hwdata;
    //for loop reduced the code a lot as clearly seen
    for (int i = 0; i < 2**size_t; i=i+1) begin
      if (write_t == 1) begin
        //mem[addr_t+i] = vif.slave_cb.hwdata[8*(i+1)-1:8*i];
        mem[addr_t+i] = wdata_t[7:0];
        wdata_t >>= 8;
      end
      if (write_t == 0) begin
        //vif.slave_cb.hrdata[8*(i+1)-1:8*i] <= mem[addr_t+i];
        rdata_t <<= 8;
        rdata_t[7:0] = mem[addr_t+2**size_t-1-i];
      end
    end
    	vif.slave_cb.hrdata <= rdata_t;
    /*if(size_t == 2) begin //for each beat, 4 bytes will be accessed
    if (write_t == 1) begin
      mem[addr_t] = vif.slave_cb.hwdata[7:0];
      mem[addr_t+1] = vif.slave_cb.hwdata[15:8];
      mem[addr_t+2] = vif.slave_cb.hwdata[23:16];
      mem[addr_t+3] = vif.slave_cb.hwdata[31:24];
    end
    if (write_t == 0) begin
      vif.slave_cb.hrdata[7:0] <= mem[addr_t];
      vif.slave_cb.hrdata[15:8] <= mem[addr_t+1];
      vif.slave_cb.hrdata[23:16] <= mem[addr_t+2];
      vif.slave_cb.hrdata[31:24] <= mem[addr_t+3];
    end
   end*/
    /*if(size_t == 3) begin //for each beat, 8 bytes will be accessed
    if (write_t == 1) begin
      mem[addr_t] = vif.slave_cb.hwdata[7:0];
      mem[addr_t+1] = vif.slave_cb.hwdata[15:8];
      mem[addr_t+2] = vif.slave_cb.hwdata[23:16];
      mem[addr_t+3] = vif.slave_cb.hwdata[31:24];
      mem[addr_t+4] = vif.slave_cb.hwdata[39:32];
      mem[addr_t+5] = vif.slave_cb.hwdata[47:40];
      mem[addr_t+6] = vif.slave_cb.hwdata[55:48];
      mem[addr_t+7] = vif.slave_cb.hwdata[63:56];
    end
    if (write_t == 0) begin
      vif.slave_cb.hrdata[7:0] <= mem[addr_t];
      vif.slave_cb.hrdata[15:8] <= mem[addr_t+1];
      vif.slave_cb.hrdata[23:16] <= mem[addr_t+2];
      vif.slave_cb.hrdata[31:24] <= mem[addr_t+3];
      vif.slave_cb.hrdata[39:32] <= mem[addr_t+4];
      vif.slave_cb.hrdata[47:40] <= mem[addr_t+5];
      vif.slave_cb.hrdata[55:48] <= mem[addr_t+6];
      vif.slave_cb.hrdata[63:56] <= mem[addr_t+7];
    end
   end*/
  endtask
  
  task idle_phase();
    vif_nocb.hrdata[7:0] = 0;
    vif_nocb.hrdata[15:8] = 0;
    vif_nocb.hrdata[23:16] = 0;
    vif_nocb.hrdata[31:24] = 0;
  endtask
  
endclass

/*You fork join the arbitration grant with thehandling ahb write/read requests. 

The latter is done using nested case statements that implement the Htrans possiblities.

The responder needs to memorize previous transaction details because data phase depends on previous address phase. This is done using the collect_addr_phase();

The data is written to and read from using an associative memory called byte mem[*];

Not valid scenarios are ignored and illegal scenarios are implemented using `uvm_error.

. Same data is getting written two times (same data phase extended by one clock cycle), so last data not getting read, need to debug, it can be a clock problem or actual implementation problem. 

Update:

I took care of the case of size_t's different values by creating a generic for loop that handles both writes nand reads to the associative memory
The initial design gave the error that you can't assign unpacked to packed, so I commented it out and modified the design.

Need to implement the other features in the data_phase of the responder code.


