interface ahb_int(input logic hclk, hrst);
  logic [31:0] haddr;
  logic [2:0] hburst;
  logic [6:0] hprot;
  logic [2:0] hsize;
  logic hnonsec;
  logic hexcl;
  logic [1:0] htrans;
  logic [31:0] hwdata;
  logic [31:0] hrdata;
  logic hwrite;
  logic hreadyout;
  logic [1:0] hresp;
  logic hexokay;
  
  clocking master_cb@(posdedge hclk);
    default input #0; 
    default output #1;
    input  hrst;
    output haddr;
    output hburst;
    output hprot;
    output hsize;
    output hnonsec;
    output hexcl;
    output htrans;
    output hwdata;
    input  hrdata;
    output hwrite;
    input  hreadyout;
    input  hresp;
    input  hexokay;
  endclocking
  
  clocking slave_cb@(posdedge hclk);
    default input #0; 
    default output #1;
    input  hrst;
    input  haddr;
    input  hburst;
    input  hprot;
    input  hsize;
    input  hnonsec;
    input  hexcl;
    input  htrans;
    input  hwdata;
    output hrdata;
    input  hwrite;
    output hreadyout;
    output hresp;
    output hexokay;
  endclocking
  
  clocking mon_cb@(posdedge hclk);
    default input #0;
    input hrst;
    input haddr;
    input hburst;
    input hprot;
    input hsize;
    input hnonsec;
    input hexcl;
    input htrans;
    input hwdata;
    input hrdata;
    input hwrite;
    input hreadyout;
    input hresp;
    input hexokay;
  endclocking
  
  modport master_mp(clocking master_cb);
  modport slave_mp(clocking slave_cb);
  modport mon_mp(clocking mon_cb);
  
endinterface
    
/*In the ahb_interface, we created clocking blocks for the master, slave and monitor. Then, created the respective modports.

In the driver, we used the master. In the responder, the slave. In the monitor, the monitor. Also, when cb was on the left we replaced = by <=.

The clocking block doesn't require signal sizes, only directions are needed (input/output) because they are in the interface already.

After doing this, many synchronization issues got resolved. The write works perfectly.
For the read however, the data phase got delayed by one cycle, if it didn't everything would be good.

Added an idle phase for HTRANS_IDLE_IDLE to reset vif.slave_cb.hrdata values to 0.

[Added @(posedge arb_vif.hclk); at end of arbitration phase to avoid potential race condition; however, read got collected two times, second time it collects perfectly or duplication actually.]

* We see a redundant read data phase as well as the second read data phase with duplicate initial read due (!to data phase being delayed by one cycle) the address phase being extended to 3 cycles which makes the read data phase face the same issue. Also, we need to debug why hbusreq and hlock are X values even though we reset them to 0 in top.sv.


//used for normal transactions