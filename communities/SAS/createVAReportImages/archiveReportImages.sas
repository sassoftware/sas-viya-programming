/******************************************************************************\
* Copyright 2022 SAS Institute Inc.
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
*
* All code below is intended to be submitted in a SAS Studio 2021.2.4 (or later) 
* session within a SAS Viya 2021.2.4 (or later) environment which contains the  
* SAS Viya services that are being called.
*
\******************************************************************************/


/*retrieve service endpoint*/
%let BASE_URI=%sysfunc(getoption(servicesbaseurl));
%let reportID = <- report uri ->;
%let height=800px;
%let width=600px;
%let workDir = %sysfunc(getoption(work));
%let zipArchiveName = myZipArchive.zip;
%put &workdir;

/* Create macro to generate images from reportObjects */
%macro createVAReportObjectImage(reportUri,reportObjectId);

filename imgfile "&workDir/myOutputImage_&reportObjectId..svg";
proc http method="GET"
     oauth_bearer=sas_services
	 url="&BASE_URI/visualAnalytics/reports/&reportUri/svg?size=&height,&width&reportObject=&reportObjectId."
	 	out=imgfile;
run;

ods package add file="&workDir/myOutputImage_&reportObjectId..svg" mimetype="application/x-compress";
ods package publish archive properties(archive_name="&zipArchiveName" archive_path="&workDir");

%mend;

/* Get the report objects and their IDs */

/* create filenames to hold responses*/
filename rcontent temp;

/* Make request */
proc http 
	 oauth_bearer=sas_services	 
	 method="GET"
     url="&BASE_URI/reports/reports/&reportID/content/elements?characteristics=visualElement" 
	 /* place response in filenames */
	 	out=rcontent;
		headers
		"Accept"="application/vnd.sas.collection+json";
run;

/* read in response */
libname rcontent json;

/* check for report elements */
data reportElementsCheck;
set rcontent.items;
run;

/* Determine if any report objects were found.   */

proc sql;
create table typeTest as select *
from dictionary.columns
where libname = "WORK" and memname = "REPORTELEMENTSCHECK" and upcase(name) = "TYPE";
quit;

/* get number of obs */
data _NULL_;
	if 0 then set typeTest nobs=n;
	call symputx('nrows',n);
	stop;
run;



%if %upcase(&nrows)>0 %then
      %do;
/*return only graph objects*/
		data reportElements;
		set rcontent.items;
		where Type eq "Graph";
		run;

			/* Print the results! */
			title "The Report's Visual Elements are Below:"; 
			proc report data=reportElements nowd;
				columns name Type Label;
				define name / group 'Report Object Name';
				define Type / group 'Report Object Type';
				define Label /display 'Report Object Label';
			run; 

/* generate dynamic code */
data reportElementsCode;
set reportElements;
length code $ 500;
code = '%createVAReportObjectImage(' || "&reportID." || ','  || trim(name) || ')';
keep name type label code;
run;

/* open ODS package */
ods package open nopf;

/* Create the images dynamically */
data _NULL_;
set reportElementsCode;
call execute(code);
run;

/* open close package */
ods package close;


/* filename to the zip archive in teh workd directory */

filename src "&workDir/&zipArchiveName"  recfm=n;

/* filename using FILESRVC to the "My Folder" destination in the Viya Content folders */

filename dest filesrvc folderuri='/folders/folders/@myFolder' filename="&zipArchiveName" debug=http recfm=n;

/* copy the file: output return code and any message */
data _null_;
rc=fcopy("src","dest");
msg=sysmsg();
put rc=;
put msg=;
run;

filename src clear;
filename dest clear;



%end;
%else
%do;
	  /* create message for user if there are no graphs found */
      %put NOTE: The report VA you selected has no Graph Elements;
%end;


