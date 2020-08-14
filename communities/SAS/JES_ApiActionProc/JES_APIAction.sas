/******************************************************************************\
* Copyright 2020 SAS Institute Inc.
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
*
* All code must be saved as part of a SAS Viya Job definition.  The job must 
* be executed with the parameter _action=form,execute
*
\******************************************************************************/

* Base URI for the service call;
%let BASE_URI=%sysfunc(getoption(servicesbaseurl));

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

proc sort data=getReportDataSources;
	by reportCasLib reportCasTable;
run;

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
	run;

%mend getLoadedTables;

proc sql;
	create table reportCaslibs as select distinct caslibEndpoint from getReportDataSources;
quit;

data _NULL_;
	set reportCaslibs;
	call execute('%getLoadedTables(' || trim(caslibEndpoint) || ')');
run;

data getReportDataSourcesCheck;
	set getReportDataSources;
	where state="loaded";
run;


data _NULL_;
	if 0 then set getReportDataSourcesCheck(where=(state='loaded')) nobs=n;
	call symputx('nrows',n);
	stop;
run;

 %if &nrows=0 %then %do;
	/* Print the results! */
	title "The Report's Data Source(s) are Listed Below"; 
	proc report data=getReportDataSources nowd missing;
		columns reportCasLib reportCasTable state flag;
		define flag/computed noprint;
		define reportCasLib / group 'CAS Library';
		define reportCasTable /Group 'CAS Table';
		define state /Group 'CAS Table State';
		compute flag;
		if state='loaded' then do;
		call define('_c3_', 'style','style={background=green foreground=white}');
		end;
		if state='unloaded' then do;
		call define('_c3_', 'style','style={background=red}');
		end;
		endcomp;
	run; 

 %end;
 %else %do;
	%macro getTableInfo(reportCasLib,reportCasTable);
			cas myses;
			ods exclude all; 
			proc cas;
			table.tableInfo result=S 
			caslib="&reportCasLib"
			table="&reportCasTable";
			val = findtable(s);
			saveresult val dataout=work.casTableInfo;
			run;
			ods exclude none; 
			
			data casTableInfo;
			set casTableInfo;
			reportCasLib = "&reportCasLib";
			rename name = reportCasTable;
			run;
			
			proc sort data=casTableInfo;
			by reportCasLib reportCasTable;
			run;
			
			Data getReportDataSources;
				Merge getReportDataSources(in=T1) casTableInfo(in=T2);
					If T1;
					by reportCasLib reportCasTable;
			keep reportCasLib reportCasTable state Name Rows Columns Compressed;
			run;

			
			
			%mend getTableInfo;
			
			data getReportDataSourcesExe;
			set getReportDataSources;
			length code $ 1000;
			code = '%getTableInfo(' || trim(reportCasLib) || ',' ||  trim(reportCasTable) ||')';
			where state="loaded";
			run;
			
			data _NULL_;
			set getReportDataSourcesExe;
			call execute(code);
			run;

			data getReportDataSources;
			set getReportDataSources;
			if compressed=1 then compressDesc = "Yes";
			else if compressed=0 then compressDesc = "No";
			run;

			title "The Report's Data Source Details are Listed Below"; 
			proc report data=getReportDataSources nowd missing;
				columns reportCasLib reportCasTable state Columns Rows compressDesc flag;
				define flag/computed noprint;
				define reportCasLib / group 'CAS Library';
				define reportCasTable /Group 'CAS Table';
				define state /Group 'CAS Table State';
			 	define Columns/Group 'Columns' format=comma8.;
				define Rows /Group 'Rows' format=comma8.;
				define compressDesc / Display 'Data Compressed?';
				compute flag;
				if state='loaded' then do;
				call define('_c3_', 'style','style={background=green foreground=white}');
				end;
				if state='unloaded' then do;
				call define('_c3_', 'style','style={background=red}');
				end;
				if state='unloaded' then do;
				call define('_c3_', 'style','style={background=red}');
				call define('_c6_', 'style','style={ foreground=white}');
				call define('_c7_', 'style','style={ foreground=white}');
				call define('_c10_', 'style','style={ foreground=white}');
				end;
				endcomp;
			run; 
			cas myses terminate;
 %end;

