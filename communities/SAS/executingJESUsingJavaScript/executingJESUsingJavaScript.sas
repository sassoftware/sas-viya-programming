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
* This is a SAS Job Execution Service version of the following example from the
* product documentation:
*
* https://go.documentation.sas.com/?cdcId=jobexeccdc&cdcVersion=2.2&docsetId=jobexecug&docsetTarget=n0qo7wn74c7mxjn0z46prg7xtakd.htm&locale=en#p0izfftsr05kf6n1barcj6t2pxid
*
* Output: HTML Output that allows users to submit a SAS Viya Job request in an HTML 
*         prompt and displays the output in a DIV tag.
*
* All code must be saved as part of a SAS Viya Job definition.  The job must 
* be executed with the parameter _action=form,execute
*
\******************************************************************************/

  Title "Student Listing - Gender: &genderParameter";
  proc print data = sashelp.class noobs;
  where sex="&genderParameter";
  run;
