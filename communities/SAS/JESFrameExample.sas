/******************************************************************************\
* Copyright 2019 SAS Institute Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* https://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Author: Michael Drutar
*
* This is a SAS Job Execution Service version of the following support.sas.com 
* example:
* http://support.sas.com/kb/43/723.html
*
* Output: HTML Output Which allows users to submit a SAS® Viya Job request in an HTML 
*         Frame and displays the output in another HTML Frame
*
* All code must be saved as the source code for a SAS Viya Job definition.  The job must 
* be executed with the parameter _output_type=html
*
\******************************************************************************/
*ProcessBody;

%let BASE_URI=%sysfunc(getoption(servicesbaseurl));
%macro main;

  %global reqtype _odsstyle;

%macro first_request;

 /* This is the first request. Create an HTML page with Frames. */

data _null_;
 
  file _webout;

  thissrv = "&_URL";
  thispgm = urlencode("&_program");

  put '<html>';
  put '<table>';
  put '<tr>';
  put '<td width="20%">';
  put '<iframe name="frame1" scrolling="no" width="100%" height="600" src="'
       thissrv +(-1)  '?_program=' thispgm +(-1) 
      '&reqtype=create_selection&_debug=0">';
  put '</iframe>';
  put '</td>';
  put '<td width="80%">';
  put '<iframe name="frame2" width="100%" height="600" >'; 
  put '</iframe>';
  put '</td></tr>';
  put '</table>';
 
  put '</html>';  
  run; 

%mend first_request;

%macro create_selection;

  /* This is the Second Request. Create the Selection Memu. */

  /* Get age groups */
 proc summary data=sashelp.class;
   class age;
   output out=summary;
 run;

 data _null_;
  set summary end=alldone;
  file _webout;
  if _n_ = 1 then do;
     thissrv = "&_URL";
     thispgm = "&_program";
     put '<html>';
     put '<h3>Student Report</h3>';
     put '<FORM ACTION="'  thissrv +(-1) '" method=get  target="frame2">';
     put '<input type="hidden" name="_program" value="'
          thispgm +(-1) '">';
     put '<input type="hidden" name=reqtype value="report">';
     put '<input type="hidden" name=_ODSDEST value="html">';
     put '<b>Select Age: </b>';
     put '<select name="age">';
  end;
  if age ne . then do;
       put '<OPTION VALUE="' age '">' age;
  end;
  if alldone then do;
    put '</select>';
    put '<br><br>';
    put '<input type="submit" value="Submit">';
    put '</form>';
    put '</html>';
  end;

 run;

%mend create_selection;

%macro create_report;   /* Produce the report */

  %let _odsstyle=BarrettsBlue;

			

  Title "Students who are age &age";
  proc print data = sashelp.class noobs;
    where age = &age;
  run;

		  

%mend create_report;


%if "&reqtype" = "create_selection" %then %do;
       /* Produce the Selection Menu   */

    %create_selection;

%end;
%else %if "&reqtype" = "report" %then %do;
       /* Produce the Report   */

    %create_report;

%end;

%else %do;
        /* Produce the HTML page that contains Frames */

    %first_request;

%end;


%mend main;

%main;
