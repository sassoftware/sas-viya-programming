* Use BASE SAS Java Object to run Python model;
%_dmcas_addToClasspath(/opt/opensource/bin);
%let WORK_DIR = /opt/opensource;
%let PYTHON_EXEC_COMMAND = /opt/anaconda3/bin/python;
%let PYTHON_SCRIPT = ModelStudioPython.py;

data _null_; 
   length rtn_val 8; 
   python_pgm = "&WORK_DIR./&PYTHON_SCRIPT"; 
   tbl = substr("&dm_data", 10);
   nodeid = "&dm_nodeid";
   &dm_data_caslib;
   python_call = cat('"', trim(python_pgm), '" "', trim(caslib), '" "', trim(tbl), '" "', trim(nodeid),'"'); 
   declare javaobj j("dev.SASJavaExec", "&PYTHON_EXEC_COMMAND", python_call);  
   j.callIntMethod("executeProcess", rtn_val); 
run;

* Print 10 observations from scored data;
proc print data=&dm_casiocalib..&dm_nodeid._score(obs=10);
run;
