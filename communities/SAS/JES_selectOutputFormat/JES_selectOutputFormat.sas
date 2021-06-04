/******************************************************************************\
* Copyright 2021 SAS Institute Inc.
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
* All code must be saved as part of a SAS Viya Job definition.  The job must 
* be executed with the parameter _action=form,execute
*
\******************************************************************************/

/* Environment Setup */
* Base URI for the service call;
%let BASE_URI=%sysfunc(getoption(servicesbaseurl));


/* API Call to the relationships service to retrieve the VA report's data sources */
filename rep_ds temp;

proc http url="&BASE_URI/relationships/relationships/?resourceUri=/reports/reports/&JESParameter"
		method='get' 
    oauth_bearer=sas_services
	out=rep_ds;
run;
quit;

libname rep_ds json;

/* extract information about the data sources */
data getReportDataSources;
set rep_ds.items;
	where index(relatedResourceUri,"/casManagement/servers")>0 and scan(relatedResourceUri,-2,'/')='tables';
	reportCasLib = (scan(relatedResourceUri,-3,'/'));
	reportCasTable = (scan(relatedResourceUri,-1,'/'));
	caslibEndpoint = tranwrd(relatedResourceUri,trim('/tables/' || reportCasTable),'');
	keep reportCasLib reportCasTable caslibEndpoint;
run;

/* sort the output data table */
proc sort data=getReportDataSources;
	by reportCasLib reportCasTable;
run;

/* This macro makes an API request to the CAS Management API to determine if each table is loaded into CAS */
%macro getLoadedTables(caslibURI);

	filename clibinfo temp;
	proc http url="&BASE_URI/&caslibURI/tables?limit=10000"
	 method='get'
	 oauth_bearer=sas_services
	 out=clibinfo;
	run; 

	libname clibinfo json;
	data formatTable;
	set clibinfo.items;
	rename name = reportCasTable
	caslibName = reportCasLib;
	run;

	proc sort data=formatTable;
	by reportCasLib reportCasTable;
	run;

	Data getReportDataSources;
		Merge getReportDataSources(in=T1) formatTable(in=T2);
			If T1;
			by reportCasLib reportCasTable;
	keep reportCasLib reportCasTable state;
	if state='' then state='unloaded';
	else state=state;
	run;

%mend getLoadedTables;

/* get a distict list of caslibs for the VA report's data sources */
proc sql;
	create table reportCaslibs as select distinct caslibEndpoint from getReportDataSources;
quit;

/* run the getLoadedTables macro  */
data _NULL_;
	set reportCaslibs;
	call execute('%getLoadedTables(' || trim(caslibEndpoint) || ')');
run;

/* do some formatting  */
data getReportDataSourcesRPT;
	set getReportDataSources;
		reportCasLib = upcase(reportCasLib);
		state = upcase(state);
		label reportCasLib="Caslib" reportCasTable="Table" state="State";
run;


/* 		generate the appropriate output */
/* 		user selected JSON as output - return output as json file */
%if %qtrim("&_output_type") = "json" %then %do;
proc json out=_webout nosastags pretty;
  export getReportDataSourcesRPT;
run; quit;
%end;

/* 		user selected ODS as output - return output as SAS ODS Table */		
%if %qtrim("&_output_type") = "ods_html5" %then %do;
	
	proc print data=getReportDataSourcesRPT noobs label;
	label reportCasLib='CAS Library'
	reportCasTable='CAS Table'
	state='CAS Table State';
	run;

%end;
