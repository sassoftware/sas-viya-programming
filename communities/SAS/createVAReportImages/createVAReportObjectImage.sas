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

%let BASE_URI=%sysfunc(getoption(servicesbaseurl));
%let reportID = <- report uri ->;
%let reportObjectId = <- report object id ->;
%let height=800px;
%let width=600px;
filename imgfile filesrvc folderuri='/folders/folders/@myFolder' filename="myOutputImage_&reportObjectId..svg";
proc http method="GET"
     oauth_bearer=sas_services
	 url="&BASE_URI/visualAnalytics/reports/&reportID/svg?size=&height,&width&reportObject=&reportObjectId."
	 	out=imgfile;
run;