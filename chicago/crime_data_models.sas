******************************************************************************/
*Copyright (c) 2016 by SAS Institute Inc., Cary, NC 27513 USA                */
*                                                                            */
*                                                                            */
* Unless required by applicable law or agreed to in writing, software        */
* distributed under the License is distributed on an "AS IS" BASIS,          */ 
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */ 
*                                                                            */ 
*                                                                            */  
******************************************************************************/;

option casport=5570 cashost="cloud.example.com";
cas casauto;
caslib _all_ assign;


/********************* Create Formats *********************/
proc format casfmtlib="chicagofmts" sessref=casauto;
    value $fbi
    '01A' = 'Homicide 1st & 2nd Degree'
    '02' = 'Criminal Sexual Assault'
    '03' = 'Robbery'
    '04A' = 'Aggravated Assault'
    '04B' = 'Aggravated Battery'
    '05' = 'Burglary'
    '06' = 'Larceny'
    '07' = 'Motor Vehicle Theft'
    '08A' = 'Simple Assault'
    '08B' = 'Simple Battery'
    '09' = 'Arson'
    '10' = 'Forgery & Counterfeiting'
    '11' = 'Fraud'
    '12' = 'Embezzlement'
    '13' = 'Stolen Property'
    '14' = 'Vandalism'
    '15' = 'Weapons Violation'
    '16' = 'Prostitution'
    '17' = 'Criminal Sexual Abuse'
    '18' = 'Drug Abuse'
    '19' = 'Gambling'
    '20' = 'Offenses Against Family'
    '22' = 'Liquor License'
    '24' = 'Disorderly Conduct'
    '26' = 'Misc Non-Index Offense'
;
value suntosat 
    1 = 'Sunday'
    2 = 'Monday'
    3 = 'Tuesday'
    4 = 'Wednesday'
    5 = 'Thursday'
    6 = 'Friday'
    7 = 'Saturday';
run;
title;

/********************* Load the Data into SAS Cloud Analytic Services *********************/
/*If you did not asssign the name chicago when you created the SAS library, substitute the value that you used. */
libname chicago "/path/to/chicago";

proc casutil;
    load data=chicago.census replace;
    load data=chicago.crime replace;

    contents casdata="crime";
    contents casdata="census";
quit;

/********************* Merge the Data Sets *********************/

libname mycas cas sessref=casauto;

data mycas.crimeCensus/ sessref=casauto;
   merge mycas.crime(in=in1) mycas.census(in=in2);
   by community_area;
   if in1;
run;

proc casutil;
   contents casdata="crimeCensus";
quit;


/********************* Explore Data Using ODS Graphics *********************/ 
/*Overall Arrest Rate */
ods graphics / width=5in antialiasmax=5600;
proc sgplot data=mycas.crimeCensus;
  title "Overall Arrest Rate";
  vbar arrest;
run;

/*Crime and Arrest Rate by Offense*/
ods graphics / width=8in antialiasmax=5600;
proc sgplot data=mycas.crimeCensus;
   vbar fbi_code / categoryorder=respdesc group=arrest;
   xaxis display=(nolabel);
run;

/*To see the arrest rate as a percentage of crimes for the top 10 crimes, you can run the following code:*/ 
proc mdsummary data=mycas.crimeCensus;
  var arrest_code ;
  groupby fbi_code;
  output out=mycas.crimeGrouped;
run;

proc sql outobs=10;
  select fbi_code as "FBI Code"n, 
         _Nobs_ as Crimes,
         _Sum_ as Arrests,
         (_Sum_ / _Nobs_) * 100 format=5.2 as Pct
  from mycas.crimeGrouped
  order by Crimes desc;
quit;


/*Plot Larceny and Battery by Hour*/
data mycas.larBatByHr / sessref=casauto;
    set mycas.crimeCensus;
    format dow suntosat.;
    if fbi_code in ('06', '08B');
    dow=weekday(date); /* returns 1=Sunday... */
    h=hour(timestamp);
run;

proc sort data=mycas.larBatByHr out=work.sorted;
  by dow;
run;

proc sgplot data=work.sorted;
    heatmap x=dow y=h / colorresponse=arrest_code discretex ;
    yaxis label="Hour of Day";
    xaxis discreteorder=data display=(nolabel);
run;

/*Plot Crime by per Capita Income*/
proc sgplot data=mycas.crimeCensus;
   title 'Crime incidence by Per Capita Income';     
   histogram per_capita_income;
   refline 28051 / axis=x label='U.S. Average';
   xaxis label='Per Capita Income'; 
run;


/*Crime and Arrest over Time*/
proc mdsummary data=mycas.crimeCensus;
   groupby date;
   var arrest_code;
   output out=mycas.ts;
run;

proc sgplot data=mycas.ts;
   title "Times Series of Crime and Arrest";
   series x=date y=_sum_ / legendlabel='Arrests';
   series x=date y=_nobs_ / legendlabel='Reported Crimes';
run;

/*Crime Incidents by Hardship Index*/
proc sgplot data=mycas.crimeCensus;
    title 'Percentage of Crime by Hardship Index';
    histogram hardship_index;
    density hardship_index / type=kernel;
run;


/********************* Perform Data Prep *********************/

title;
/*Split the Data into Training, Validation, and Test*/ 
proc partition data=mycas.crimeCensus partind seed=9878 samppct=30 samppct2=10; 
   target arrest;
   output out=mycas.cwpart copyvars=(_all_); 
run; 

/*Check the Proportion of the Sampling*/ 
proc mdsummary data=mycas.cwpart;
   groupby _partind_;
   var arrest_code;
   output out=mycas.split;
run;

proc print data=mycas.split;
run;


/*Explore the Cardinality*/
proc cardinality data=mycas.cwpart outcard=mycas.card maxlevels=20;
    var _numeric_;
    var _char_;
run;

proc print data=mycas.card;
run; 



/********************* Create Models *********************/


/* Create Macro Variables */
%let dset=mycas.CWpart;
%let outdir=~;
%let target=arrest_code;
%let nom_input=fbi_code location_description domestic beat district ward community_area;
%let int_input= percent: per_capita_income hardship_index;

/* Create a Predictive Model */
proc forest data=&dset. ntrees=10 minleafsize=5 outmodel=mycas.model_forest;
   target &target. / level=nominal; 
   input &nom_input. / level=nominal;
   input &int_input. / level=interval;
   partition rolevar=_partind_(train='0' validate='1');
   output out=mycas.ap_scored_forest copyvars=(_partind_ &target);
   title "Random Forest";
run; 


/* Create Decision Trees with Gradient Boosting */
proc gradboost data=&dset. maxdepth=8 minleafsize=5 seed=9878 outmodel=mycas.model_gradboost;
   target &target. / level=nominal;
   input &nom_input. / level=nominal;
   input &int_input. / level=interval;
   partition rolevar=_partind_(train='0' validate='1');
   output out=mycas.ap_scored_gradboost copyvars=(_partind_ &target.);
   title "Gradient Boost";
run;  


/* Perform Logistic Regression with Variable Selection */
proc logselect data=&dset. noclprint;
   class &target. &nom_input.;
   model &target.(event='1') = &nom_input. &int_input.;
   selection method=stepwise (choose=validate) ;
   partition rolevar=_partind_(train='0' validate='1');
   code file="&outdir./logselect1.sas";
   title "Logistic Regression";
run;

/* The SAS log can include Notes for operations on missing values. */
data mycas.ap_scored_logistic;
   set &dset.;
   %include "&outdir./logselect1.sas";
   p_&target.1=p_&target.;
   p_&target.0=1-p_&target.;
run;


/* Build a Decision Tree */
proc treesplit data=&dset. minleafsize=5 maxdepth=8 outmodel=mycas.model_treesplit;
    target &target. /level=nominal;
    input &nom_input. /level=nominal;
    input &int_input. /level=interval;
    partition rolevar=_partind_(train='0' validate='1');
    output out=mycas.ap_scored_treesplit copyvars=(_partind_ &target);
    title "Decision Tree";
run;

/********************* Assess Models *********************/
/*Create a Macro for the ASSESS Procedure*/

%macro assess_model(prefix=, var_evt=, var_nevt=);
proc assess data=mycas.ap_scored_&prefix. nbins=10;
  input &var_evt.;
  target &target. / level=nominal event='1';
  fitstat pvar=&var_nevt. / pevent='0';
  by _partind_;

ods output fitstat=work.&prefix._fitstat
           rocinfo=work.&prefix._rocinfo
           liftinfo=work.&prefix._liftinfo;
run;
%mend assess_model;

title "Assess Forest";
%assess_model(prefix=forest, 
              var_evt=p_arrest_code1, 
              var_nevt=p_arrest_code0);

title "Assess Gradient Boost";
%assess_model(prefix=gradboost, 
              var_evt=p_arrest_code1, 
              var_nevt=p_arrest_code0);

title "Assess Logistic Regression";
%assess_model(prefix=logistic, 
              var_evt=p_arrest_code1, 
              var_nevt=p_arrest_code0);

title "Assess Decision Tree";
%assess_model(prefix=treesplit, 
              var_evt=p_arrest_code1, 
              var_nevt=p_arrest_code0);

/*Prepare ROC and Lift Data Sets for Plotting*/
data work.all_rocinfo;
  set work.logistic_rocinfo(keep=sensitivity fpr _partind_ in=l) 
      work.forest_rocinfo(keep=sensitivity fpr _partind_ in=f)
      work.treesplit_rocinfo(keep=sensitivity fpr _partind_ in=t)
      work.gradboost_rocinfo(keep=sensitivity fpr _partind_ in=g);

  length model $ 16;
  select;
    when (l) model='Logistic';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (t) model='TreeSplit';
  end;
run;

data work.all_liftinfo;
  set work.logistic_liftinfo(keep=depth lift cumlift _partind_ in=l)
      work.forest_liftinfo(keep=depth lift cumlift _partind_ in=f)
      work.treesplit_liftinfo(keep=depth lift cumlift _partind_ in=t)
      work.gradboost_liftinfo(keep=depth lift cumlift _partind_ in=g);

  length model $ 16;
  select;
    when (l) model='Logistic';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (t) model='TreeSplit';
  end;
run;


/*Plot ROC Curves*/
ods graphics on;

/* _partind_=2 specifies the test partition */
proc sgplot data=work.all_rocinfo(where=(_partind_=2)) aspect=1;
  title "ROC Curves";
  series x=fpr y=sensitivity / group=model;
  lineparm x=0 y=0 slope=1 / transparency=.7;
  yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
  xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
run; 

/*Plot Lift*/
proc sgplot data=work.all_liftinfo(where=(_partind_=2));
   title "Lift Chart";
   xaxis label="Percentile" grid;
   series x=depth y=lift / group=model markers 
                           markerattrs=(symbol=circlefilled);
run;

/* Create Fit Statistics */
%macro print_fitstats(prefix=);
proc print data=work.&prefix._fitstat;
run;
%mend print_fitstats;

title "Forest Fit Statistics";
%print_fitstats(prefix=forest);

title "Gradient Boosting Fit Statistics";
%print_fitstats(prefix=gradboost);

title "Logistic Fit Statistics";
%print_fitstats(prefix=logistic);

title "TreeSplit Fit Statistics";
%print_fitstats(prefix=treesplit);


/********************* Score New Data *********************/
/*If you receive an error in the SAS log that is related to missing a CA trust list, *******/ 
/*then locate the trustedcerts.pem file that is part of the SAS installation, submit code***/
/*like the following, and then rerun. *****/

* options sslcalistloc="/path/to/trustedcerts.pem";

/*This option enables Server Name Indication on UNIX*/
options set=SSL_USE_SNI=1;

/*Retrieve the columns that are used in the model only.   */
/*Retrieve data with a date after 15FEB16                 */
filename chicago url 'https://data.cityofchicago.org/resource/6zsd-86xi.json?$query=
select%20id%2C%20case_number%2C%20date%2C%20community_area
%2C%20fbi_code%2C%20location_description%20%2Cdomestic%20%2Cbeat
%20%2Cdistrict%20%2Cward%20%2Carrest
%20where%20date%20%3E%20%272016-02-15%27';   
libname chicago sasejson ;


data mycas.arrest (replace=yes) err;
  set chicago.root(rename=(
      date=tmpts arrest=arrest_code domestic=tmpds 
      beat=tbeat community_area=tca district=tdis   id=tid 
      ward=tward
      ));

  if arrest_code eq 0 then arrest = 'false';
  else arrest = 'true';
  if tmpds eq 0 then domestic = 'false';
  else domestic = 'true';

  beat           = input(tbeat, best12.);
  community_area = input(tca,   best12.);
  district       = input(tdis,  best12.);
  id             = input(tid,   best12.);
  ward           = input(tward, best12.);
 
  format fbi_code $fbi. location_description $47.
         arrest domestic $5.
         arrest_code 8. date mmddyy10. timestamp datetime. ;

  pos = kindex(tmpts, 'T');
  if -1 eq pos then output err;
  date = input(substr(tmpts,1,pos-1), yymmdd10.);
  time = input(substr(tmpts,pos+1), time.);
  timestamp = dhms(date,0,0,time);

  drop tmpts pos time tmpds tbeat tca tdis tid tward;
  output mycas.arrest;
run;

data mycas.latest_crimes(replace=yes);
    merge mycas.arrest(in=in1) mycas.census(in=in2);
    by community_area;
    if in1;
run;


/* Score the Latest Data */
data mycas.latest_logistic (replace=yes);
  set mycas.latest_crimes;
  %include "&outdir./logselect1.sas";
  p_&target.1=p_&target.;
  p_&target.0=1-p_&target.;
run;

proc treesplit data=mycas.latest_crimes inmodel=mycas.model_treesplit noprint;
   target &target. /level=nominal;
   input &nom_input. /level=nominal;
   input &int_input. /level=interval;
   output out=mycas.latest_treesplit copyvars=(&target);
run;

proc gradboost data=mycas.latest_crimes inmodel=mycas.model_gradboost noprint;
   output out=mycas.latest_gradboost copyvars=(&target);
run;

proc forest data=mycas.latest_crimes inmodel=mycas.model_forest noprint;
   output out=mycas.latest_forest copyvars=(&target);
run;

/* Assess the Models on the Latest Data */
%macro assess_latest(prefix=, var_evt=, var_nevt=);
proc assess data=mycas.latest_&prefix. nbins=10;
  input &var_evt.;
  target &target. / level=nominal event='1';
  fitstat pvar=&var_nevt. / pevent='0';

ods output fitstat=work.&prefix._lfitstat
           rocinfo=work.&prefix._lrocinfo
           liftinfo=work.&prefix._lliftinfo;
run;
%mend assess_latest;

title "Assess Decision Tree";
%assess_latest(prefix=treesplit, var_evt=p_arrest_code1, var_nevt=p_arrest_code0);
title "Assess Forest";
%assess_latest(prefix=forest, var_evt=p_arrest_code1, var_nevt=p_arrest_code0);
title "Assess Gradient Boost";
%assess_latest(prefix=gradboost, var_evt=p_arrest_code1, var_nevt=p_arrest_code0);
title "Assess Logistic Regression";
%assess_latest(prefix=logistic, var_evt=p_arrest_code1, var_nevt=p_arrest_code0);


/* Combine the ROC and lift data sets that were written to the Work libref the SAS client  */
data work.latest_rocinfo;
  set work.logistic_lrocinfo(keep=sensitivity fpr in=l)
      work.forest_lrocinfo(keep=sensitivity fpr in=f)
      work.treesplit_lrocinfo(keep=sensitivity fpr in=t)
      work.gradboost_lrocinfo(keep=sensitivity fpr in=g);

  length model $ 16;
  select;
    when (l) model='Logistic';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (t) model='TreeSplit';
  end;
run;


data work.latest_liftinfo;
  set work.logistic_lliftinfo(keep=depth lift cumlift in=l)
      work.forest_lliftinfo(keep=depth lift cumlift in=f)
      work.treesplit_lliftinfo(keep=depth lift cumlift in=t)
      work.gradboost_lliftinfo(keep=depth lift cumlift in=g);

  length model $ 16;
  select;
    when (l) model='Logistic';
    when (f) model='Forest';
    when (g) model='GradientBoosting';
    when (t) model='TreeSplit';
  end;
run;

/* Plot ROC Curves and Lift Chart */
ods graphics;
proc sgplot data=work.latest_rocinfo aspect=1;
  title "ROC Curves";
  title2 "Latest Data";
  series x=fpr y=sensitivity / group=model;
  lineparm x=0 y=0 slope=1 / transparency=.7;
  yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
  xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
run;

proc sgplot data=work.latest_liftinfo;
  title "Lift Chart";
  title2 "Latest Data";
  xaxis label="Percentile" grid;
  series x=depth y=lift / group=model markers markerattrs=(symbol=circlefilled);
run;

