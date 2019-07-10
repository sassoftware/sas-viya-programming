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
* Input: A SAS dataset named reportList containing two variables: 
*           reportName - A SAS Viya Visual Analytics Report's Name
* 			reportURI - A SAS Visual Analytics Report's URI
*
* Output: The input SAS Viya Visual Analytics Report's data source list 
*         displayed in the SAS Studio Results window
*
* All code included in this section must be submitted in a SAS Studio 5.1 (or later) 
* session within a Viya 3.4 (or later) environment which contains the SAS Viya services 
* that are being called. 
\******************************************************************************/

/* Create an example dataset with some reports */
data reportList;
   length reportName $ 100 ID $ 100;
   input reportName $ ID $;
   infile datalines dlm=',';
   datalines;
Retail Insights,cbf97b0a-457d-4b4f-8913-547e0cdf390c
Warranty Analysis,eb897d90-e4fd-4bdf-a764-b61af5c339b8
;
run;

/* Sort Dataset by ID */
proc sort data=reportList;
by ID;
run;



/* -------------------------------------------------------------- */
/*                  Begin Macro Definition                        */
/* -------------------------------------------------------------- */

%macro get_VA_report_datasrc(reportName,reportUri);
/*retrieve service endpoint*/
%let BASE_URI=%sysfunc(getoption(servicesbaseurl));

/* create filenames to hold responses*/
filename rcontent temp;

/* Make request */
proc http 
	 oauth_bearer=sas_services	 
	 method="GET"
     url="&BASE_URI/reports/reports/&reportUri/content" 
	/* place response in filenames */
	 	out=rcontent;
		headers
		"Accept"="application/vnd.sas.report.content+json";
run;

/* read in response */
libname rcontent json;

/* create reporting dataset */
data listdatasources;
	length reportName $ 100 id $ 100 table $ 32 library $ 32;
	set rcontent.datasources_casresource;
		reportName = "&reportName";
		id = "&reportUri";
		keep reportName id table library;
run;

/* merge reporting dataset to the reportList dataset */
Data reportList;
	Merge reportList(in=T1) listdatasources(in=T2);
		If T1;
		by ID;
run;
%mend get_VA_report_datasrc;

/* call the macro within a data step */
/* using the reportList dataset as the input */
data _NULL_;
	set reportlist;
		call execute('%get_VA_report_datasrc(' || trim(reportName) || ',' || trim(id) || ');');
		keep name id code;
run;

/* Print the results! */
title "The Report(s) Data Sources are Listed Below"; 
proc report data=reportList nowd;
	columns ID reportName Library table;
	define ID / group 'Report ID';
	define reportName / group 'Report Name';
	define Library /display 'CAS Library';
	define table /display 'CAS Table';
run; 
