* Andrea Bruckner
  PREDICT 411, Sec 55
  Spring 2016
  Unit 03: Wine
;

********************************************************************;
* Preliminary Steps--All Models;
********************************************************************;

* Access library where data sets are stored;

%let PATH = /folders/myfolders/PREDICT_411/Wine;
%let NAME = POI;
%let LIB = &NAME..;
%let INFILE = &LIB.WINE;

%let TEMPFILE = TEMPFILE;
%let FIXFILE = FIXFILE;

libname &NAME. "&PATH.";

proc contents data=&INFILE.;
run;

proc print data=&INFILE.(obs=10);
run;

********************************************************************;
* Data Exploration/EDA--All Models;
********************************************************************;

* EDA for numeric variables;
proc means data=&INFILE. min max mean median n nmiss;
run;

proc freq data=&INFILE.;
table TARGET;
run;

proc univariate data=&INFILE. noprint;
histogram TARGET;
run;

proc sgplot data=&INFILE.;
vbar TARGET / datalabel missing;
run;

proc means data=&INFILE. mean var;
where TARGET > 0;
var TARGET;
run;
* mean > variance, meaning this is underdispersion (pg 104 GLM book);

* EDA visualization of numeric variables;
data edafile;
set &INFILE.;
drop INDEX TARGET;
run;

proc univariate data=edafile plot;
run;

proc freq data=&INFILE.;
table TARGET * LabelAppeal /missing;
run;

proc freq data=&INFILE.;
table TARGET * STARS /missing;
run;

proc freq data=&INFILE.;
table STARS * LabelAppeal /missing;
run;

proc freq data=&INFILE.;
table LabelAppeal * STARS /missing;
run;

proc means data=&INFILE. mean median;
class STARS / missing;
var TARGET;
run;

* Correlation matrix;
* STARS and LabelAppeal have strongest positive correlation with TARGET
and AcidIndex has strongest negative correaltion with TARGET.

ods graphics on;
proc corr data=&INFILE. plots=matrix; * Too much info to include scatterplots;
var
TARGET
AcidIndex
Alcohol
Chlorides
CitricAcid
Density
FixedAcidity
FreeSulfurDioxide
LabelAppeal
ResidualSugar
STARS
Sulphates
TotalSulfurDioxide
VolatileAcidity
pH
;
run;
ods graphics off;

proc corr data=&INFILE. plots=matrix; * Too much info to include scatterplots;
var
TARGET
AcidIndex
LabelAppeal
STARS
;
run;
ods graphics off;

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;
run;

proc freq data=&TEMPFILE.;
table TARGET_FLAG /missing;
run;

proc univariate data=&TEMPFILE. noprint;
histogram TARGET TARGET_AMT;
run;

proc means data=&TEMPFILE. nmiss mean median min max;
class TARGET_FLAG;
var
AcidIndex
Alcohol
Chlorides
CitricAcid
Density
FixedAcidity
FreeSulfurDioxide
LabelAppeal
ResidualSugar
STARS
Sulphates
TotalSulfurDioxide
VolatileAcidity
pH
;
run;
* Reveals that TARGET_FLAG = 0 has 1/3 as many observations as TARGET_FLAG = 1,
and that the nmiss for each variable in TARGET_FLAG = 0 is about 1/3 as many as
the nmiss in TARGET_FLAG = 1 (which makes sense) BUT the nmiss for STARS in TARGET_FLAG = 0
is 2x as high as the nmiss for STARS for TARGET_FLAG = 1. This shows that unranked wines
do not sell as well as ranked wines;

********************************************************************;
* Data Preparation--Model 1;
********************************************************************;

* To be imputed:

ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

title "Model 1";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

proc means data=&TEMPFILE. mean median;
class IMP_STARS;
var TARGET;
run;

proc means data=&TEMPFILE. mean median;
class M_IMP_STARS;
var TARGET;
run;
* M_IMP_STARS = 1 has a much lower mean than M_IMP_STARS = 0, meaning
that if a wine wasn't reviewed (so = 1 since we had to impute a review),
people are less likely to buy the wine. Mentioned 1 hr into 5/19 video;

********************************************************************;
* Model Creation--Model 1;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

* Variable Selection;

proc reg data=&TEMPFILE.;
model TARGET =

FixedAcidity
VolatileAcidity
CitricAcid
IMP_ResidualSugar
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS

/ adjrsq aic bic mse cp vif selection = stepwise slentry =0.10 slstay=0.10;
;
run;

********************************************************************;
* Model Scoring--Using WINE--Model 1;
********************************************************************;

%let SCORE_ME = &LIB.WINE;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 1";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.52176
+VolatileAcidity*-0.13119
+CitricAcid*0.03465
+IMP_Chlorides*-0.17025
+IMP_FreeSulfurDioxide*0.00040814
+IMP_TotalSulfurDioxide*0.00027367
+Density*-1.10164
+IMP_pH*-0.05496
+IMP_Sulphates*-0.04615
+IMP_Alcohol*0.01401
+LabelAppeal*0.43481
+AcidIndex*-0.28193
+IMP_STARS*1.00205
;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 1;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 1";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.52176
+VolatileAcidity*-0.13119
+CitricAcid*0.03465
+IMP_Chlorides*-0.17025
+IMP_FreeSulfurDioxide*0.00040814
+IMP_TotalSulfurDioxide*0.00027367
+Density*-1.10164
+IMP_pH*-0.05496
+IMP_Sulphates*-0.04615
+IMP_Alcohol*0.01401
+LabelAppeal*0.43481
+AcidIndex*-0.28193
+IMP_STARS*1.00205
;

if P_TARGET < 0 then P_TARGET = 0;

keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Exporting the Scored Model--Model 1;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine01.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 2;
********************************************************************;

* To be imputed:

ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

title "Model 2";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

********************************************************************;
* Model Creation--Model 2;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

* Variable Selection;

proc reg data=&TEMPFILE.;
model TARGET =

FixedAcidity
VolatileAcidity
CitricAcid
IMP_ResidualSugar
M_IMP_ResidualSugar
IMP_Chlorides
M_IMP_Chlorides
IMP_FreeSulfurDioxide
M_IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
M_IMP_TotalSulfurDioxide
Density
IMP_pH
M_IMP_pH
IMP_Sulphates
M_IMP_Sulphates
IMP_Alcohol
M_IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/ adjrsq aic bic mse cp vif selection = stepwise slentry =0.10 slstay=0.10;
;
run;

********************************************************************;
* Model Scoring--Using WINE--Model 2;
********************************************************************;

%let SCORE_ME = &LIB.WINE;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 2";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.72952
+VolatileAcidity*-0.09907
+IMP_Chlorides*-0.12149
+IMP_FreeSulfurDioxide*0.00028409
+IMP_TotalSulfurDioxide*0.00022879
+Density*-0.8728
+IMP_pH*-0.03415
+IMP_Sulphates*-0.03191
+IMP_Alcohol*0.01359
+LabelAppeal*0.45422
+AcidIndex*-0.20819
+IMP_STARS*0.67236
+M_IMP_STARS*-1.76601
;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 2;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 2";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.72952
+VolatileAcidity*-0.09907
+IMP_Chlorides*-0.12149
+IMP_FreeSulfurDioxide*0.00028409
+IMP_TotalSulfurDioxide*0.00022879
+Density*-0.8728
+IMP_pH*-0.03415
+IMP_Sulphates*-0.03191
+IMP_Alcohol*0.01359
+LabelAppeal*0.45422
+AcidIndex*-0.20819
+IMP_STARS*0.67236
+M_IMP_STARS*-1.76601
;

if P_TARGET < 0 then P_TARGET = 0;

keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Exporting the Scored Model--Model 2;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine02.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 3;
********************************************************************;

* To be imputed:

ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

title "Model 3";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 2;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

********************************************************************;
* Model Creation--Model 3;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

* Variable Selection;

proc reg data=&TEMPFILE.;
model TARGET =

FixedAcidity
VolatileAcidity
CitricAcid
IMP_ResidualSugar
M_IMP_ResidualSugar
IMP_Chlorides
M_IMP_Chlorides
IMP_FreeSulfurDioxide
M_IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
M_IMP_TotalSulfurDioxide
Density
IMP_pH
M_IMP_pH
IMP_Sulphates
M_IMP_Sulphates
IMP_Alcohol
M_IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/ adjrsq aic bic mse cp vif selection = stepwise slentry =0.10 slstay=0.10;
;
run;

********************************************************************;
* Model Scoring--Using WINE--Model 3;
********************************************************************;

%let SCORE_ME = &LIB.WINE;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 3";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 2;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.66823
+VolatileAcidity*-0.1017
+IMP_Chlorides*-0.11987
+IMP_FreeSulfurDioxide*0.00027546
+IMP_TotalSulfurDioxide*0.00023117
+Density*-0.83177
+IMP_pH*-0.03293
+IMP_Sulphates*-0.02977
+IMP_Alcohol*0.0131
+LabelAppeal*0.4365
+AcidIndex*-0.20681
+IMP_STARS*0.6781
+M_IMP_STARS*-2.05113
;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 3;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 3";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 2;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

P_TARGET = 4.66823
+VolatileAcidity*-0.1017
+IMP_Chlorides*-0.11987
+IMP_FreeSulfurDioxide*0.00027546
+IMP_TotalSulfurDioxide*0.00023117
+Density*-0.83177
+IMP_pH*-0.03293
+IMP_Sulphates*-0.02977
+IMP_Alcohol*0.0131
+LabelAppeal*0.4365
+AcidIndex*-0.20681
+IMP_STARS*0.6781
+M_IMP_STARS*-2.05113
;

if P_TARGET < 0 then P_TARGET = 0;

keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

proc means data=DEPLOYFILE;
var P_TARGET;
run;

********************************************************************;
* Exporting the Scored Model--Model 3;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine03.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 2+ (PROC REG, GENMOD, etc. for comparison;
********************************************************************;

* To be imputed:

ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

title "Model 2+";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

proc freq data=&TEMPFILE.;
table STARS*TARGET_FLAG /missing;
run;
* The Row Pct is 60.67 for TARGET_FLAG = 0 for wines with missing STARS, meaning that
unranked wines don't sell 60.67% of the time while they do sell at least 1 case 39.33% of the time;

proc freq data=&TEMPFILE.;
table IMP_STARS*TARGET_FLAG /missing;
run;
* The Row Pct for both the above freqs is 100 when TARGET_FLAG = 1, meaning that
3 and 4 star wines will sell at least 1 case (Winter Video 43 min);

proc univariate data=&TEMPFILE. noprint;
histogram
ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS
;
run;

proc univariate data=&TEMPFILE. plots;
var
ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS
;
run;

********************************************************************;
* Model Creation--Model 2+;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc reg data=&FIXFILE.;
model TARGET =
 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/ adjrsq aic bic mse cp vif;
output out=&FIXFILE. p=X_REGRESSION;
run;
quit;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=nb;
output out=&FIXFILE. p=X_GENMOD_NB;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=poi;
output out=&FIXFILE. p=X_GENMOD_POI;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=zip;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZIP pzero=X_GENMOD_PZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP = 1.5844
+VolatileAcidity*-0.0172
+IMP_Chlorides*-0.0238
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.288
+IMP_pH*-0.0003
+IMP_Sulphates*-0.0024
+IMP_Alcohol*0.0062
+LabelAppeal*0.2407
+AcidIndex*-0.0362
+IMP_STARS*0.1076
+M_IMP_STARS*-0.1098
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6738
+IMP_STARS*-1.6172
+LabelAppeal*1.1623
+M_IMP_STARS*3.1537
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_SCORE_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
run;

* Quality Check: Each pair of variables below should be almost identical,
that is X_GENMOD_PZERO = P_SCORE_ZERO for the most part.
If you look at X_GENMOD_ZIP and P_SCORE_ZIP, these values should also be similar (which they are);

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_PZERO P_SCORE_ZERO;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZIP P_SCORE_ZIP;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=zinb;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZINB pzero=X_GENMOD_NBZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP2 = 1.5793
+VolatileAcidity*-0.0168
+IMP_Chlorides*-0.0236
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2913
+IMP_pH*0.0002
+IMP_Sulphates*-0.0022
+IMP_Alcohol*0.0063
+LabelAppeal*0.2392
+AcidIndex*-0.035
+IMP_STARS*0.1071
+M_IMP_STARS*-0.1047
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8179
+IMP_STARS*-1.3829
+LabelAppeal*1.0112
+M_IMP_STARS*3.0104
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_SCORE_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
run;

* Quality Check: Each pair of variables below should be almost identical--They are;
proc print data=&FIXFILE.(obs=10);
var X_GENMOD_NBZERO P_SCORE_ZERO2;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZINB P_SCORE_ZINB;
run;

proc print data=&FIXFILE.(obs=10);
run;

*data &FIXFILE.;
*set &FIXFILE.;
*drop 
X_GENMOD_ZINB
X_GENMOD_NBZERO
TEMP
P_SCORE_ZIP_ALL
P_SCORE_ZERO
P_SCORE_ZIP
X_GENMOD_ZINB2
X_GENMOD_NBZERO2
TEMP2
IMP_FreeSulfurDioxid
IMP_TotalSulfurDioxi
P_SCORE_ZINB_ALL
P_SCORE_ZERO2
P_SCORE_ZINB
;
*run;

* To print for report--easy to compare;
data FIXFILE_ROUNDED;
set &FIXFILE.;
X_REGRESSION 		= round( X_REGRESSION,1);
X_GENMOD_NB 		= round( X_GENMOD_NB,1);
X_GENMOD_POI 		= round( X_GENMOD_POI,1);
X_GENMOD_ZIP	    = round( X_GENMOD_ZIP,1);
X_GENMOD_ZINB       = round( X_GENMOD_ZINB,1);
run;

proc print data=FIXFILE_ROUNDED(obs=10);
var TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

proc univariate data=FIXFILE_ROUNDED noprint;
histogram TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc logistic data=&FIXFILE.;
model TARGET_FLAG(ref="0") = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
;
output out=&FIXFILE. p=X_LOGIT_PROB;
run;

proc print data=&FIXFILE.(obs=10);
var TARGET_FLAG X_LOGIT_PROB;
run;

proc genmod data=&FIXFILE.;
model TARGET_AMT = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=poi
;
output out=&FIXFILE. p=X_GENMOD_HURDLE;
run;

proc print data=&FIXFILE.(obs=10);
run;

********************************************************************;
* Model Scoring--Using WINE--Model 2+;
********************************************************************;

%let SCORE_ME = &LIB.WINE; * Need the &FIXFILE. for this since it contains
X_GENMOD etc for comparisons;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 2+";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine02;
P_REGRESSION = 4.72952
+VolatileAcidity*-0.09907
+IMP_Chlorides*-0.12149
+IMP_FreeSulfurDioxide*0.00028409
+IMP_TotalSulfurDioxide*0.00022879
+Density*-0.8728
+IMP_pH*-0.03415
+IMP_Sulphates*-0.03191
+IMP_Alcohol*0.01359
+LabelAppeal*0.45422
+AcidIndex*-0.20819
+IMP_STARS*0.67236
+M_IMP_STARS*-1.76601
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine02nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.8221
+VolatileAcidity*-0.0316
+IMP_Chlorides*-0.0377
+IMP_FreeSulfurDioxide*0.0001
+IMP_TotalSulfurDioxide*0.0001
+Density*-0.2874
+IMP_pH*-0.0131
+IMP_Sulphates*-0.0119
+IMP_Alcohol*0.0037
+LabelAppeal*0.1581
+AcidIndex*-0.0818
+IMP_STARS*0.1744
+M_IMP_STARS*-0.91
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine02zip;
* PROC GENMOD ZIP;
TEMP = 1.5844
+VolatileAcidity*-0.0172
+IMP_Chlorides*-0.0238
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.288
+IMP_pH*-0.0003
+IMP_Sulphates*-0.0024
+IMP_Alcohol*0.0062
+LabelAppeal*0.2407
+AcidIndex*-0.0362
+IMP_STARS*0.1076
+M_IMP_STARS*-0.1098
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6738
+IMP_STARS*-1.6172
+LabelAppeal*1.1623
+M_IMP_STARS*3.1537
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine02zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.5793
+VolatileAcidity*-0.0168
+IMP_Chlorides*-0.0236
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2913
+IMP_pH*0.0002
+IMP_Sulphates*-0.0022
+IMP_Alcohol*0.0063
+LabelAppeal*0.2392
+AcidIndex*-0.035
+IMP_STARS*0.1071
+M_IMP_STARS*-0.1047
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8179
+IMP_STARS*-1.3829
+LabelAppeal*1.0112
+M_IMP_STARS*3.0104
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Part 1;
P_LOGIT_PROB = 5.0488								+
+VolatileAcidity*-0.1934
+IMP_Chlorides*-0.1509
+IMP_FreeSulfurDioxide*0.000608
+IMP_TotalSulfurDioxide*0.000843
+Density*-0.7312
+IMP_pH*-0.1934
+IMP_Sulphates*-0.1072
+IMP_Alcohol*-0.02
+LabelAppeal*-0.5706
+AcidIndex*-0.3938
+IMP_STARS*1.3264
+M_IMP_STARS*-2.5459
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 1.178
+VolatileAcidity*-0.0131
+IMP_Chlorides*-0.0222
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.3742
+IMP_pH*0.0096
+IMP_Sulphates*0.0001
+IMP_Alcohol*0.009
+LabelAppeal*0.2937
+AcidIndex*-0.0199
+IMP_STARS*0.1195
+M_IMP_STARS*-0.1202
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

********************************************************************;
* Model Validation Macro Code--Model 2+;
********************************************************************;

%macro FIND_ERROR( DATAFILE, P, MEANVAL );

%let ERRFILE 	= ERRFILE;
%let MEANFILE	= MEANFILE;

data &ERRFILE.;
set &DATAFILE.;
	ERROR_MEAN		= abs( TARGET - &MEANVAL.)	**&P.;
	ERROR_REG		= abs( TARGET - P_REGRESSION )	**&P.;
	ERROR_NBPOI		= abs( TARGET - P_NBPOI )	**&P.;
	ERROR_ZIP		= abs( TARGET - P_ZIP )	**&P.;
	ERROR_ZINB		= abs( TARGET - P_ZINB )**&P.;
	ERROR_HURDLE	= abs( TARGET - P_HURDLE )	**&P.;
	ERROR_ENSEMBLE	= abs( TARGET - P_ENSEMBLE )**&P.;
run;

proc means data=&ERRFILE. noprint;
output out=&MEANFILE.
	mean(ERROR_MEAN)    = ERROR_MEAN
	mean(ERROR_REG)	    = ERROR_REG
	mean(ERROR_NBPOI)   = ERROR_NBPOI
	mean(ERROR_ZIP)     = ERROR_ZIP
	mean(ERROR_ZINB)    = ERROR_ZINB
	mean(ERROR_HURDLE)	= ERROR_HURDLE
	mean(ERROR_ENSEMBLE)= ERROR_ENSEMBLE
	;
run;

data &MEANFILE.;
length P 8.;
set &MEANFILE.;
	P		= &P.;
	ERROR_MEAN	= ERROR_MEAN**(1.0/&P.);
	ERROR_REG 	= ERROR_REG**(1.0/&P.);
	ERROR_NBPOI = ERROR_NBPOI**(1.0/&P.);
	ERROR_ZIP 	= ERROR_ZIP**(1.0/&P.);
	ERROR_ZINB 	= ERROR_ZINB**(1.0/&P.);
	ERROR_HURDLE 	= ERROR_HURDLE**(1.0/&P.);
	ERROR_ENSEMBLE 	= ERROR_ENSEMBLE**(1.0/&P.);
	drop _TYPE_;
run;

proc print data=&MEANFILE.;
run;

%mend;

%FIND_ERROR( DEPLOYFILE, 1	, 3.0290739 );
%FIND_ERROR( DEPLOYFILE, 2	, 3.0290739 );

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 2+;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 2+";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine02;
P_REGRESSION = 4.72952
+VolatileAcidity*-0.09907
+IMP_Chlorides*-0.12149
+IMP_FreeSulfurDioxide*0.00028409
+IMP_TotalSulfurDioxide*0.00022879
+Density*-0.8728
+IMP_pH*-0.03415
+IMP_Sulphates*-0.03191
+IMP_Alcohol*0.01359
+LabelAppeal*0.45422
+AcidIndex*-0.20819
+IMP_STARS*0.67236
+M_IMP_STARS*-1.76601
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine02nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.8221
+VolatileAcidity*-0.0316
+IMP_Chlorides*-0.0377
+IMP_FreeSulfurDioxide*0.0001
+IMP_TotalSulfurDioxide*0.0001
+Density*-0.2874
+IMP_pH*-0.0131
+IMP_Sulphates*-0.0119
+IMP_Alcohol*0.0037
+LabelAppeal*0.1581
+AcidIndex*-0.0818
+IMP_STARS*0.1744
+M_IMP_STARS*-0.91
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine02zip;
* PROC GENMOD ZIP;
TEMP = 1.5844
+VolatileAcidity*-0.0172
+IMP_Chlorides*-0.0238
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.288
+IMP_pH*-0.0003
+IMP_Sulphates*-0.0024
+IMP_Alcohol*0.0062
+LabelAppeal*0.2407
+AcidIndex*-0.0362
+IMP_STARS*0.1076
+M_IMP_STARS*-0.1098
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6738
+IMP_STARS*-1.6172
+LabelAppeal*1.1623
+M_IMP_STARS*3.1537
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine02zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.5793
+VolatileAcidity*-0.0168
+IMP_Chlorides*-0.0236
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2913
+IMP_pH*0.0002
+IMP_Sulphates*-0.0022
+IMP_Alcohol*0.0063
+LabelAppeal*0.2392
+AcidIndex*-0.035
+IMP_STARS*0.1071
+M_IMP_STARS*-0.1047
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8179
+IMP_STARS*-1.3829
+LabelAppeal*1.0112
+M_IMP_STARS*3.0104
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Part 1;
P_LOGIT_PROB = 5.0488								+
+VolatileAcidity*-0.1934
+IMP_Chlorides*-0.1509
+IMP_FreeSulfurDioxide*0.000608
+IMP_TotalSulfurDioxide*0.000843
+Density*-0.7312
+IMP_pH*-0.1934
+IMP_Sulphates*-0.1072
+IMP_Alcohol*-0.02
+LabelAppeal*-0.5706
+AcidIndex*-0.3938
+IMP_STARS*1.3264
+M_IMP_STARS*-2.5459
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 1.178
+VolatileAcidity*-0.0131
+IMP_Chlorides*-0.0222
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.3742
+IMP_pH*0.0096
+IMP_Sulphates*0.0001
+IMP_Alcohol*0.009
+LabelAppeal*0.2937
+AcidIndex*-0.0199
+IMP_STARS*0.1195
+M_IMP_STARS*-0.1202
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

*keep INDEX P_TARGET;

run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc print data=DEPLOYFILE(obs=10);
run;

********************************************************************;
* Exporting the Scored Model--Model 2+;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine02hurdle2.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 4 (PROC REG, GENMOD, etc. for comparison;
********************************************************************;

* To be imputed:

ResidualSugar
Chlorides
FreeSulfurDioxide
TotalSulfurDioxide
pH
Sulphates
Alcohol
STARS

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

title "Model 4";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal < -0.5  then 
		IMP_STARS = 1;	
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

proc freq data=&TEMPFILE.;
table STARS*TARGET_FLAG /missing;
run;

proc freq data=&TEMPFILE.;
table IMP_STARS*TARGET_FLAG /missing;
run;

proc univariate data=&TEMPFILE. noprint;
histogram
IMP_ResidualSugar
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
IMP_pH
IMP_Sulphates
IMP_Alcohol
IMP_STARS
;
run;

proc univariate data=&TEMPFILE. plots;
var
IMP_ResidualSugar
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
IMP_pH
IMP_Sulphates
IMP_Alcohol
IMP_STARS
;
run;

********************************************************************;
* Model Creation--Model 4;
********************************************************************;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc reg data=&FIXFILE.;
model TARGET =
 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/ adjrsq aic bic mse cp vif;
output out=&FIXFILE. p=X_REGRESSION;
run;
quit;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=nb;
output out=&FIXFILE. p=X_GENMOD_NB;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=poi;
output out=&FIXFILE. p=X_GENMOD_POI;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=zip;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZIP pzero=X_GENMOD_PZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP = 1.5441
+VolatileAcidity*-0.0173
+IMP_Chlorides*-0.0247
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2793
+IMP_pH*0.0003
+IMP_Sulphates*-0.0019
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0359
+IMP_STARS*0.1209
+M_IMP_STARS*-0.1229
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.851
+IMP_STARS*-1.5926
+LabelAppeal*1.3092
+M_IMP_STARS*4.0468
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_SCORE_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
run;

* Quality Check: Each pair of variables below should be almost identical,
that is X_GENMOD_PZERO = P_SCORE_ZERO for the most part.
If you look at X_GENMOD_ZIP and P_SCORE_ZIP, these values should also be similar (which they are);

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_PZERO P_SCORE_ZERO;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZIP P_SCORE_ZIP;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=zinb;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZINB pzero=X_GENMOD_NBZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP2 = 1.5437
+VolatileAcidity*-0.0169
+IMP_Chlorides*-0.0245
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2836
+IMP_pH*0.0006
+IMP_Sulphates*-0.0018
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0348
+IMP_STARS*0.1192
+M_IMP_STARS*-0.123
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.9311
+IMP_STARS*-1.3814
+LabelAppeal*1.1607
+M_IMP_STARS*3.7476
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_SCORE_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
run;

* Quality Check: Each pair of variables below should be almost identical--They are;
proc print data=&FIXFILE.(obs=10);
var X_GENMOD_NBZERO P_SCORE_ZERO2;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZINB P_SCORE_ZINB;
run;

proc print data=&FIXFILE.(obs=10);
run;

* To print for report--easy to compare;
data FIXFILE_ROUNDED;
set &FIXFILE.;
X_REGRESSION 		= round( X_REGRESSION,1);
X_GENMOD_NB 		= round( X_GENMOD_NB,1);
X_GENMOD_POI 		= round( X_GENMOD_POI,1);
X_GENMOD_ZIP	    = round( X_GENMOD_ZIP,1);
X_GENMOD_ZINB       = round( X_GENMOD_ZINB,1);
run;

proc print data=FIXFILE_ROUNDED(obs=10);
var TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

proc univariate data=FIXFILE_ROUNDED noprint;
histogram TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc logistic data=&FIXFILE.;
model TARGET_FLAG(ref="0") = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
;
output out=&FIXFILE. p=X_LOGIT_PROB;
run;

proc print data=&FIXFILE.(obs=10);
var TARGET_FLAG X_LOGIT_PROB;
run;

proc genmod data=&FIXFILE.;
model TARGET_AMT = 	
VolatileAcidity
IMP_Chlorides
IMP_FreeSulfurDioxide
IMP_TotalSulfurDioxide
Density
IMP_pH
IMP_Sulphates
IMP_Alcohol
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=poi
;
output out=&FIXFILE. p=X_GENMOD_HURDLE;
run;

proc print data=&FIXFILE.(obs=10);
run;

********************************************************************;
* Model Scoring--Using WINE--Model 4;
********************************************************************;

%let SCORE_ME = &LIB.WINE;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 4";

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal < -0.5  then 
		IMP_STARS = 1;	
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine04reg;
P_REGRESSION = 4.69333
+VolatileAcidity*-0.10206
+IMP_Chlorides*-0.12243
+IMP_FreeSulfurDioxide*0.00027792
+IMP_TotalSulfurDioxide*0.0002336
+Density*-0.8268
+IMP_pH*-0.03178
+IMP_Sulphates*-0.02991
+IMP_Alcohol*0.01336
+LabelAppeal*0.41477
+AcidIndex*-0.20846
+IMP_STARS*0.66688
+M_IMP_STARS*-2.01681
;
********************************************************************;
* Kaggle Submission wine04nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.8081
+VolatileAcidity*-0.0318
+IMP_Chlorides*-0.0376
+IMP_FreeSulfurDioxide*0.0001
+IMP_TotalSulfurDioxide*0.0001
+Density*-0.2815
+IMP_pH*-0.0129
+IMP_Sulphates*-0.0117
+IMP_Alcohol*0.0036
+LabelAppeal*0.1547
+AcidIndex*-0.0815
+IMP_STARS*0.1774
+M_IMP_STARS*-0.9754
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine04zip;
* PROC GENMOD ZIP;
TEMP = 1.5441
+VolatileAcidity*-0.0173
+IMP_Chlorides*-0.0247
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2793
+IMP_pH*0.0003
+IMP_Sulphates*-0.0019
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0359
+IMP_STARS*0.1209
+M_IMP_STARS*-0.1229
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.851
+IMP_STARS*-1.5926
+LabelAppeal*1.3092
+M_IMP_STARS*4.0468
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP= P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine04zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.5437
+VolatileAcidity*-0.0169
+IMP_Chlorides*-0.0245
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2836
+IMP_pH*0.0006
+IMP_Sulphates*-0.0018
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0348
+IMP_STARS*0.1192
+M_IMP_STARS*-0.123
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.9311
+IMP_STARS*-1.3814
+LabelAppeal*1.1607
+M_IMP_STARS*3.7476
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Part 1;
P_LOGIT_PROB = 4.7591								+
+VolatileAcidity*-0.199
+IMP_Chlorides*-0.1486
+IMP_FreeSulfurDioxide*0.000582
+IMP_TotalSulfurDioxide*0.000847
+Density*-0.5724
+IMP_pH*-0.1844
+IMP_Sulphates*-0.0967
+IMP_Alcohol*-0.0208
+LabelAppeal*-0.7702
+AcidIndex*-0.3876
+IMP_STARS*1.3929
+M_IMP_STARS*-3.1228
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 1.1441
+VolatileAcidity*-0.0129
+IMP_Chlorides*-0.0228
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.3626
+IMP_pH*0.0095
+IMP_Sulphates*0.0004
+IMP_Alcohol*0.0088
+LabelAppeal*0.2868
+AcidIndex*-0.0196
+IMP_STARS*0.1299
+M_IMP_STARS*-0.1618
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;
run;

********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together.
I've changed P_TARGET to be more descriptive of each model. At the end, I rounded each 
to the nearest case so that I could compare the sum of how many cases were predicted 
with each model to the sum of the TARGET;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

********************************************************************;
* Model Validation Macro Code--Model 4;
********************************************************************;

%macro FIND_ERROR( DATAFILE, P, MEANVAL );

%let ERRFILE 	= ERRFILE;
%let MEANFILE	= MEANFILE;

data &ERRFILE.;
set &DATAFILE.;
	ERROR_MEAN		= abs( TARGET - &MEANVAL.)	**&P.;
	ERROR_REG		= abs( TARGET - P_REGRESSION )	**&P.;
	ERROR_NBPOI		= abs( TARGET - P_NBPOI )	**&P.;
	ERROR_ZIP		= abs( TARGET - P_ZIP )	**&P.;
	ERROR_ZINB		= abs( TARGET - P_ZINB )**&P.;
	ERROR_HURDLE	= abs( TARGET - P_HURDLE )	**&P.;
	ERROR_ENSEMBLE	= abs( TARGET - P_ENSEMBLE )**&P.;
run;

proc means data=&ERRFILE. noprint;
output out=&MEANFILE.
	mean(ERROR_MEAN)    = ERROR_MEAN
	mean(ERROR_REG)	    = ERROR_REG
	mean(ERROR_NBPOI)   = ERROR_NBPOI
	mean(ERROR_ZIP)     = ERROR_ZIP
	mean(ERROR_ZINB)    = ERROR_ZINB
	mean(ERROR_HURDLE)	= ERROR_HURDLE
	mean(ERROR_ENSEMBLE)= ERROR_ENSEMBLE
	;
run;

data &MEANFILE.;
length P 8.;
set &MEANFILE.;
	P		= &P.;
	ERROR_MEAN	= ERROR_MEAN**(1.0/&P.);
	ERROR_REG 	= ERROR_REG**(1.0/&P.);
	ERROR_NBPOI = ERROR_NBPOI**(1.0/&P.);
	ERROR_ZIP 	= ERROR_ZIP**(1.0/&P.);
	ERROR_ZINB 	= ERROR_ZINB**(1.0/&P.);
	ERROR_HURDLE 	= ERROR_HURDLE**(1.0/&P.);
	ERROR_ENSEMBLE 	= ERROR_ENSEMBLE**(1.0/&P.);
	drop _TYPE_;
run;

proc print data=&MEANFILE.;
run;

%mend;

%FIND_ERROR( DEPLOYFILE, 1	, 3.0290739 );
%FIND_ERROR( DEPLOYFILE, 2	, 3.0290739 );

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 4;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 4";

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal < -0.5  then 
		IMP_STARS = 1;	
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine04reg;
P_REGRESSION = 4.69333
+VolatileAcidity*-0.10206
+IMP_Chlorides*-0.12243
+IMP_FreeSulfurDioxide*0.00027792
+IMP_TotalSulfurDioxide*0.0002336
+Density*-0.8268
+IMP_pH*-0.03178
+IMP_Sulphates*-0.02991
+IMP_Alcohol*0.01336
+LabelAppeal*0.41477
+AcidIndex*-0.20846
+IMP_STARS*0.66688
+M_IMP_STARS*-2.01681
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine04nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.8081
+VolatileAcidity*-0.0318
+IMP_Chlorides*-0.0376
+IMP_FreeSulfurDioxide*0.0001
+IMP_TotalSulfurDioxide*0.0001
+Density*-0.2815
+IMP_pH*-0.0129
+IMP_Sulphates*-0.0117
+IMP_Alcohol*0.0036
+LabelAppeal*0.1547
+AcidIndex*-0.0815
+IMP_STARS*0.1774
+M_IMP_STARS*-0.9754
;

P_NBPOI = exp(TEMP);
********************************************************************;
* Kaggle Submission wine04zip;
* PROC GENMOD ZIP;
TEMP = 1.5441
+VolatileAcidity*-0.0173
+IMP_Chlorides*-0.0247
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2793
+IMP_pH*0.0003
+IMP_Sulphates*-0.0019
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0359
+IMP_STARS*0.1209
+M_IMP_STARS*-0.1229
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.851
+IMP_STARS*-1.5926
+LabelAppeal*1.3092
+M_IMP_STARS*4.0468
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP= P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine04zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.5437
+VolatileAcidity*-0.0169
+IMP_Chlorides*-0.0245
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.2836
+IMP_pH*0.0006
+IMP_Sulphates*-0.0018
+IMP_Alcohol*0.0061
+LabelAppeal*0.2286
+AcidIndex*-0.0348
+IMP_STARS*0.1192
+M_IMP_STARS*-0.123
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.9311
+IMP_STARS*-1.3814
+LabelAppeal*1.1607
+M_IMP_STARS*3.7476
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Kaggle Submission wine04hurdle;
* Part 1;
P_LOGIT_PROB = 4.7591								+
+VolatileAcidity*-0.199
+IMP_Chlorides*-0.1486
+IMP_FreeSulfurDioxide*0.000582
+IMP_TotalSulfurDioxide*0.000847
+Density*-0.5724
+IMP_pH*-0.1844
+IMP_Sulphates*-0.0967
+IMP_Alcohol*-0.0208
+LabelAppeal*-0.7702
+AcidIndex*-0.3876
+IMP_STARS*1.3929
+M_IMP_STARS*-3.1228
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 1.1441
+VolatileAcidity*-0.0129
+IMP_Chlorides*-0.0228
+IMP_FreeSulfurDioxide*0
+IMP_TotalSulfurDioxide*0
+Density*-0.3626
+IMP_pH*0.0095
+IMP_Sulphates*0.0004
+IMP_Alcohol*0.0088
+LabelAppeal*0.2868
+AcidIndex*-0.0196
+IMP_STARS*0.1299
+M_IMP_STARS*-0.1618
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
********************************************************************;
* Kaggle Submission wine04ensemble;
P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

*keep INDEX P_TARGET;

run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc print data=DEPLOYFILE(obs=10);
run;

*proc means data=DEPLOYFILE;
*var P_TARGET;
*run;

********************************************************************;
* Exporting the Scored Model--Model 4;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine04ensemble.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 5 (PROC REG, GENMOD, etc. for comparison;
********************************************************************;

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

title "Model 5";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;
run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

proc freq data=&TEMPFILE.;
table STARS*TARGET_FLAG /missing;
run;
* The Row Pct is 60.67 for TARGET_FLAG = 0 for wines with missing STARS, meaning that
unranked wines don't sell 60.67% of the time while they do sell at least 1 case 39.33% of the time;

proc freq data=&TEMPFILE.;
table IMP_STARS*TARGET_FLAG /missing;
run;
* The Row Pct for both the above freqs is 100 when TARGET_FLAG = 1, meaning that
3 and 4 star wines will sell at least 1 case (Winter Video 43 min);

********************************************************************;
* Model Creation--Model 5;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc reg data=&FIXFILE.;
model TARGET =
 	
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity

/ adjrsq aic bic mse cp vif;
output out=&FIXFILE. p=X_REGRESSION;
run;
quit;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 
	
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity

/link=log dist=nb;
output out=&FIXFILE. p=X_GENMOD_NB;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	

LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity

/link=log dist=poi;
output out=&FIXFILE. p=X_GENMOD_POI;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	

LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity

/link=log dist=zip;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZIP pzero=X_GENMOD_PZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP = 1.3001
+LabelAppeal*0.2408
+AcidIndex*-0.0367
+IMP_STARS*0.1075
+M_IMP_STARS*-0.1102
+IMP_Alcohol*0.0062
+VolatileAcidity*-0.0173
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6724
+IMP_STARS*-1.6165
+LabelAppeal*1.1608
+M_IMP_STARS*3.1521
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_SCORE_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
run;

* Quality Check: Each pair of variables below should be almost identical,
that is X_GENMOD_PZERO = P_SCORE_ZERO for the most part.
If you look at X_GENMOD_ZIP and P_SCORE_ZIP, these values should also be similar (which they are);

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_PZERO P_SCORE_ZERO;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZIP P_SCORE_ZIP;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 
	
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity

/link=log dist=zinb;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZINB pzero=X_GENMOD_NBZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP2 = 1.2934
+LabelAppeal*0.2393
+AcidIndex*-0.0355
+IMP_STARS*0.107
+M_IMP_STARS*-0.1052
+IMP_Alcohol*0.0063
+VolatileAcidity*-0.017
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8164
+IMP_STARS*-1.3831
+LabelAppeal*1.0105
+M_IMP_STARS*3.0096
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_SCORE_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
run;

* Quality Check: Each pair of variables below should be almost identical--They are;
proc print data=&FIXFILE.(obs=10);
var X_GENMOD_NBZERO P_SCORE_ZERO2;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZINB P_SCORE_ZINB;
run;

proc print data=&FIXFILE.(obs=10);
run;

* To print for report--easy to compare;
data FIXFILE_ROUNDED;
set &FIXFILE.;
X_REGRESSION 		= round( X_REGRESSION,1);
X_GENMOD_NB 		= round( X_GENMOD_NB,1);
X_GENMOD_POI 		= round( X_GENMOD_POI,1);
X_GENMOD_ZIP	    = round( X_GENMOD_ZIP,1);
X_GENMOD_ZINB       = round( X_GENMOD_ZINB,1);
run;

proc print data=FIXFILE_ROUNDED(obs=10);
var TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

proc univariate data=FIXFILE_ROUNDED noprint;
histogram TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc logistic data=&FIXFILE.;
model TARGET_FLAG(ref="0") = 	
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity
;
output out=&FIXFILE. p=X_LOGIT_PROB;
run;

proc print data=&FIXFILE.(obs=10);
var TARGET_FLAG X_LOGIT_PROB;
run;

proc genmod data=&FIXFILE.;
model TARGET_AMT = 	
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
IMP_Alcohol
VolatileAcidity
/link=log dist=poi
;
output out=&FIXFILE. p=X_GENMOD_HURDLE;
run;

proc print data=&FIXFILE.(obs=10);
run;

********************************************************************;
* Model Scoring--Using WINE--Model 5;
********************************************************************;

%let SCORE_ME = &LIB.WINE; * Need the &FIXFILE. for this since it contains
X_GENMOD etc for comparisons;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 5";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine05reg;
P_REGRESSION = 3.797
+LabelAppeal*0.45323
+AcidIndex*-0.21179
+IMP_STARS*0.67332
+M_IMP_STARS*-1.77558
+IMP_Alcohol*0.01336
+VolatileAcidity*-0.10104
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine05nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.5064
+LabelAppeal*0.1577
+AcidIndex*-0.0826
+IMP_STARS*0.1747
+M_IMP_STARS*-0.9133
+IMP_Alcohol*0.0036
+VolatileAcidity*-0.0322
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine05zip;
* PROC GENMOD ZIP;
TEMP = 1.3001
+LabelAppeal*0.2408
+AcidIndex*-0.0367
+IMP_STARS*0.1075
+M_IMP_STARS*-0.1102
+IMP_Alcohol*0.0062
+VolatileAcidity*-0.0173
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6724
+IMP_STARS*-1.6165
+LabelAppeal*1.1608
+M_IMP_STARS*3.1521
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine05zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.2934
+LabelAppeal*0.2393
+AcidIndex*-0.0355
+IMP_STARS*0.107
+M_IMP_STARS*-0.1052
+IMP_Alcohol*0.0063
+VolatileAcidity*-0.017
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8164
+IMP_STARS*-1.3831
+LabelAppeal*1.0105
+M_IMP_STARS*3.0096
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Kaggle Submission wine05hurdle;
* Part 1;
P_LOGIT_PROB = 3.8054								+
+LabelAppeal*-0.5661
+AcidIndex*-0.399
+IMP_STARS*1.3139
+M_IMP_STARS*-2.5394
+IMP_Alcohol*-0.0207
+VolatileAcidity*-0.1996
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 0.8394
+LabelAppeal*0.2939
+AcidIndex*-0.0208
+IMP_STARS*0.1194
+M_IMP_STARS*-0.1215
+IMP_Alcohol*0.009
+VolatileAcidity*-0.0132
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

********************************************************************;
* Model Validation Macro Code--Model 5;
********************************************************************;

%macro FIND_ERROR( DATAFILE, P, MEANVAL );

%let ERRFILE 	= ERRFILE;
%let MEANFILE	= MEANFILE;

data &ERRFILE.;
set &DATAFILE.;
	ERROR_MEAN		= abs( TARGET - &MEANVAL.)	**&P.;
	ERROR_REG		= abs( TARGET - P_REGRESSION )	**&P.;
	ERROR_NBPOI		= abs( TARGET - P_NBPOI )	**&P.;
	ERROR_ZIP		= abs( TARGET - P_ZIP )	**&P.;
	ERROR_ZINB		= abs( TARGET - P_ZINB )**&P.;
	ERROR_HURDLE	= abs( TARGET - P_HURDLE )	**&P.;
	ERROR_ENSEMBLE	= abs( TARGET - P_ENSEMBLE )**&P.;
run;

proc means data=&ERRFILE. noprint;
output out=&MEANFILE.
	mean(ERROR_MEAN)    = ERROR_MEAN
	mean(ERROR_REG)	    = ERROR_REG
	mean(ERROR_NBPOI)   = ERROR_NBPOI
	mean(ERROR_ZIP)     = ERROR_ZIP
	mean(ERROR_ZINB)    = ERROR_ZINB
	mean(ERROR_HURDLE)	= ERROR_HURDLE
	mean(ERROR_ENSEMBLE)= ERROR_ENSEMBLE
	;
run;

data &MEANFILE.;
length P 8.;
set &MEANFILE.;
	P		= &P.;
	ERROR_MEAN	= ERROR_MEAN**(1.0/&P.);
	ERROR_REG 	= ERROR_REG**(1.0/&P.);
	ERROR_NBPOI = ERROR_NBPOI**(1.0/&P.);
	ERROR_ZIP 	= ERROR_ZIP**(1.0/&P.);
	ERROR_ZINB 	= ERROR_ZINB**(1.0/&P.);
	ERROR_HURDLE 	= ERROR_HURDLE**(1.0/&P.);
	ERROR_ENSEMBLE 	= ERROR_ENSEMBLE**(1.0/&P.);
	drop _TYPE_;
run;

proc print data=&MEANFILE.;
run;

%mend;

%FIND_ERROR( DEPLOYFILE, 1	, 3.0290739 );
%FIND_ERROR( DEPLOYFILE, 2	, 3.0290739 );

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 5;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 5";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if missing(IMP_STARS) then do;
	if LabelAppeal = -1  then 
		IMP_STARS = 1;	
	else if LabelAppeal = 0 then 
		IMP_STARS = 1;
	else if LabelAppeal = 1 then 
		IMP_STARS = 2;
	else if LabelAppeal = 2 then 
		IMP_STARS = 2;
	else
		IMP_STARS = 2;
end;

* PROC REG--Kaggle Submission wine05reg;
P_REGRESSION = 3.797
+LabelAppeal*0.45323
+AcidIndex*-0.21179
+IMP_STARS*0.67332
+M_IMP_STARS*-1.77558
+IMP_Alcohol*0.01336
+VolatileAcidity*-0.10104
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine05nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.5064
+LabelAppeal*0.1577
+AcidIndex*-0.0826
+IMP_STARS*0.1747
+M_IMP_STARS*-0.9133
+IMP_Alcohol*0.0036
+VolatileAcidity*-0.0322
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine05zip;
* PROC GENMOD ZIP;
TEMP = 1.3001
+LabelAppeal*0.2408
+AcidIndex*-0.0367
+IMP_STARS*0.1075
+M_IMP_STARS*-0.1102
+IMP_Alcohol*0.0062
+VolatileAcidity*-0.0173
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = -0.6724
+IMP_STARS*-1.6165
+LabelAppeal*1.1608
+M_IMP_STARS*3.1521
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine05zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.2934
+LabelAppeal*0.2393
+AcidIndex*-0.0355
+IMP_STARS*0.107
+M_IMP_STARS*-0.1052
+IMP_Alcohol*0.0063
+VolatileAcidity*-0.017
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = -0.8164
+IMP_STARS*-1.3831
+LabelAppeal*1.0105
+M_IMP_STARS*3.0096
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Kaggle Submission wine05hurdle;
* Part 1;
P_LOGIT_PROB = 3.8054								+
+LabelAppeal*-0.5661
+AcidIndex*-0.399
+IMP_STARS*1.3139
+M_IMP_STARS*-2.5394
+IMP_Alcohol*-0.0207
+VolatileAcidity*-0.1996
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 0.8394
+LabelAppeal*0.2939
+AcidIndex*-0.0208
+IMP_STARS*0.1194
+M_IMP_STARS*-0.1215
+IMP_Alcohol*0.009
+VolatileAcidity*-0.0132
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;
*keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

*proc means data=DEPLOYFILE;
*var P_TARGET;
*run;

********************************************************************;
* Exporting the Scored Model--Model 5;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine05hurdle.csv'
   dbms=csv
   replace;
*run;

********************************************************************;
* Data Preparation--Model 6 (PROC REG, GENMOD, etc. for comparison;
********************************************************************;

* Best practice: Copy data set before messing with it;
data &TEMPFILE.;
set &INFILE.;

TARGET_FLAG = ( TARGET > 0 );
TARGET_AMT = TARGET - 1;
if TARGET_FLAG = 0 then TARGET_AMT = .;

title "Model 6";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if IMP_STARS = . then IMP_STARS = 2; * mean/median;

FixedAcidity_BIN = 0; *25p-;
if 5.2 < FixedAcidity <= 9.5 	then FixedAcidity_BIN = 1; *IQR;
if 9.5 < FixedAcidity <= 34.4 	then FixedAcidity_BIN = 2; *75p+;

VolatileAcidity_BIN = 0; *25p-;
if 0.13 < VolatileAcidity <= 0.64 	then VolatileAcidity_BIN = 1; *IQR;
if 0.64 < VolatileAcidity <= 3.68 	then VolatileAcidity_BIN = 2; *75p+;

CitricAcid_BIN = 0; *25p-;
if 0.03 < CitricAcid <= 0.58 	then CitricAcid_BIN = 1; *IQR;
if 0.58 < CitricAcid <= 3.86 	then CitricAcid_BIN = 2; *75p+;

IMP_ResidualSugar_BIN = 0; *25p-;
if -2 < IMP_ResidualSugar <= 15.9 then IMP_ResidualSugar_BIN = 1; *IQR;
if 15.9 < IMP_ResidualSugar <= 141.15 then IMP_ResidualSugar_BIN = 2; *75p+;

IMP_Chlorides_BIN = 0; *25p-;
if -0.031 < IMP_Chlorides <= 0.153 then IMP_Chlorides_BIN = 1; *IQR;
if 0.153 < IMP_Chlorides <= 1.351 then IMP_Chlorides_BIN = 2; *75p+;

IMP_FreeSulfurDioxide_BIN = 0; *25p-;
if 0 < IMP_FreeSulfurDioxide <= 70 then IMP_FreeSulfurDioxide_BIN = 1; *IQR;
if 70 < IMP_FreeSulfurDioxide <= 623 then IMP_FreeSulfurDioxide_BIN = 2; *75p+;

IMP_TotalSulfurDioxide_BIN = 0; *25p-;
if 27 < IMP_TotalSulfurDioxide <= 208 then IMP_TotalSulfurDioxide_BIN = 1; *IQR;
if 208 < IMP_TotalSulfurDioxide <= 1057 then IMP_TotalSulfurDioxide_BIN = 2; *75p+;

Density_BIN = 0; *25p-;
if 0.98772 < Density <= 1.00052 then Density_BIN = 1; *IQR;
if 1.00052 < Density <= 1.09924 then Density_BIN = 2; *75p+;

IMP_pH_BIN = 0; *25p-;
if 2.96 < IMP_pH <= 3.47 then IMP_pH_BIN = 1; *IQR;
if 3.47 < IMP_pH <= 6.13 then IMP_pH_BIN = 2; *75p+;

IMP_Sulphates_BIN = 0; *25p-;
if 0.28 < IMP_Sulphates <= 0.86 then IMP_Sulphates_BIN = 1; *IQR;
if 0.86 < IMP_Sulphates <= 4.24 then IMP_Sulphates_BIN = 2; *75p+;

IMP_Alcohol_BIN = 0; *25p-;
if 9 < IMP_Alcohol <= 12.4 then IMP_Alcohol_BIN = 1; *IQR;
if 12.4 < IMP_Alcohol <= 26.5 then IMP_Alcohol_BIN = 2; *75p+;

run;

***
Data Preparation Checks
***

* Make sure all imputations worked by seeing that everything has 12795 records--YEP;
proc print data=&TEMPFILE. (obs=10);
run;

proc means data=&TEMPFILE. min mean median n nmiss;
run;

proc freq data=&TEMPFILE.;
table STARS*TARGET_FLAG /missing;
run;

proc freq data=&TEMPFILE.;
table IMP_STARS*TARGET_FLAG /missing;
run;

proc sgplot data=&TEMPFILE.;
vbar FixedAcidity_BIN / datalabel missing;
run;

proc corr data=&TEMPFILE. plots=matrix; * Too much info to include scatterplots;
var
TARGET
AcidIndex
LabelAppeal
IMP_STARS
;
run;
ods graphics off;

proc univariate data=&TEMPFILE. noprint;
histogram
FixedAcidity_BIN
VolatileAcidity_BIN
CitricAcid_BIN
IMP_ResidualSugar_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
Density_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
;
run;

proc univariate data=&TEMPFILE. plots;
var
FixedAcidity_BIN
VolatileAcidity_BIN
CitricAcid_BIN
IMP_ResidualSugar_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
Density_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
;
run;

********************************************************************;
* Model Creation--Model 6;
********************************************************************;

* Build at least five different using the SAS procs: PROC GENMOD and PROC REG. The five models will be:
•	GENMOD with Poisson distribution
•	GENMOD with Negative Binomial distribution
•	GENMOD with Zero Inflated Poisson distribution
•	GENMOD with Zero Inflated Negative Binomial distribution
•	REGRESSION (use standard PROC REG and if you wish you may use a variable selection method)
;

* Variable Selection;

proc reg data=&TEMPFILE.;
model TARGET =

FixedAcidity_BIN
VolatileAcidity_BIN
CitricAcid_BIN
IMP_ResidualSugar_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
Density_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/ adjrsq aic bic mse cp vif selection = stepwise slentry =0.10 slstay=0.10;
;
run;


data &FIXFILE.;
set &TEMPFILE.;
run;

proc reg data=&FIXFILE.;
model TARGET =
 	
VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/ adjrsq aic bic mse cp vif;
output out=&FIXFILE. p=X_REGRESSION;
run;
quit;


proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 
	
VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/link=log dist=nb;
output out=&FIXFILE. p=X_GENMOD_NB;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	

VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/link=log dist=poi;
output out=&FIXFILE. p=X_GENMOD_POI;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 	

VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/link=log dist=zip;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZIP pzero=X_GENMOD_PZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP = 1.3285
+VolatileAcidity_BIN*-0.0141
+CitricAcid_BIN*0.0063
+IMP_Chlorides_BIN*-0.0067
+IMP_FreeSulfurDioxide_BIN*0.0063
+IMP_TotalSulfurDioxide_BIN*-0.0006
+IMP_pH_BIN*-0.0007
+IMP_Sulphates_BIN*-0.0028
+IMP_Alcohol_BIN*0.0284
+LabelAppeal*0.2327
+AcidIndex*-0.0334
+IMP_STARS*0.1062
+M_IMP_STARS*-0.1828
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = 2.5005
+IMP_STARS*-4.1348
+LabelAppeal*0.7496
+M_IMP_STARS*6.2279
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_SCORE_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
run;

* Quality Check: Each pair of variables below should be almost identical,
that is X_GENMOD_PZERO = P_SCORE_ZERO for the most part.
If you look at X_GENMOD_ZIP and P_SCORE_ZIP, these values should also be similar (which they are);

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_PZERO P_SCORE_ZERO;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZIP P_SCORE_ZIP;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc genmod data=&FIXFILE.;
model TARGET = 
	
VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS

/link=log dist=zinb;
zeromodel IMP_STARS LabelAppeal M_IMP_STARS / link=logit;
output out=&FIXFILE. pred=X_GENMOD_ZINB pzero=X_GENMOD_NBZERO;
run;

proc print data=&FIXFILE.(obs=10);
run;

data &FIXFILE.;
set &FIXFILE.;

TEMP2 = 1.3233
+VolatileAcidity_BIN*-0.0136
+CitricAcid_BIN*0.0058
+IMP_Chlorides_BIN*-0.0062
+IMP_FreeSulfurDioxide_BIN*0.0065
+IMP_TotalSulfurDioxide_BIN*-0.0011
+IMP_pH_BIN*-0.0006
+IMP_Sulphates_BIN*-0.002
+IMP_Alcohol_BIN*0.0279
+LabelAppeal*0.2336
+AcidIndex*-0.0324
+IMP_STARS*0.1057
+M_IMP_STARS*-0.1828
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = 0.5258
+IMP_STARS*-2.2112
+LabelAppeal*0.7178
+M_IMP_STARS*4.3504
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_SCORE_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
run;

* Quality Check: Each pair of variables below should be almost identical--They are;
proc print data=&FIXFILE.(obs=10);
var X_GENMOD_NBZERO P_SCORE_ZERO2;
run;

proc print data=&FIXFILE.(obs=10);
var X_GENMOD_ZINB P_SCORE_ZINB;
run;

proc print data=&FIXFILE.(obs=10);
run;

* To print for report--easy to compare;
data FIXFILE_ROUNDED;
set &FIXFILE.;
X_REGRESSION 		= round( X_REGRESSION,1);
X_GENMOD_NB 		= round( X_GENMOD_NB,1);
X_GENMOD_POI 		= round( X_GENMOD_POI,1);
X_GENMOD_ZIP	    = round( X_GENMOD_ZIP,1);
X_GENMOD_ZINB       = round( X_GENMOD_ZINB,1);
run;

proc print data=FIXFILE_ROUNDED(obs=10);
var TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

proc univariate data=FIXFILE_ROUNDED noprint;
histogram TARGET X_REGRESSION X_GENMOD_NB X_GENMOD_POI X_GENMOD_ZIP X_GENMOD_ZINB;
run;

********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;

data &FIXFILE.;
set &TEMPFILE.;
run;

proc print data=&FIXFILE.(obs=10);
run;

proc logistic data=&FIXFILE.;
model TARGET_FLAG(ref="0") = 	
VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
;
output out=&FIXFILE. p=X_LOGIT_PROB;
run;

proc print data=&FIXFILE.(obs=10);
var TARGET_FLAG X_LOGIT_PROB;
run;

proc genmod data=&FIXFILE.;
model TARGET_AMT = 	
VolatileAcidity_BIN
CitricAcid_BIN
IMP_Chlorides_BIN
IMP_FreeSulfurDioxide_BIN
IMP_TotalSulfurDioxide_BIN
IMP_pH_BIN
IMP_Sulphates_BIN
IMP_Alcohol_BIN
LabelAppeal
AcidIndex
IMP_STARS
M_IMP_STARS
/link=log dist=poi
;
output out=&FIXFILE. p=X_GENMOD_HURDLE;
run;

proc print data=&FIXFILE.(obs=10);
run;

********************************************************************;
* Model Scoring--Using WINE--Model 6;
********************************************************************;

%let SCORE_ME = &LIB.WINE; * Need the &FIXFILE. for this since it contains
X_GENMOD etc for comparisons;

* Making sure the SCORE_ME file has all 12795 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 6";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if IMP_STARS = . then IMP_STARS = 2; * mean/median;

FixedAcidity_BIN = 0; *25p-;
if 5.2 < FixedAcidity <= 9.5 	then FixedAcidity_BIN = 1; *IQR;
if 9.5 < FixedAcidity <= 34.4 	then FixedAcidity_BIN = 2; *75p+;

VolatileAcidity_BIN = 0; *25p-;
if 0.13 < VolatileAcidity <= 0.64 	then VolatileAcidity_BIN = 1; *IQR;
if 0.64 < VolatileAcidity <= 3.68 	then VolatileAcidity_BIN = 2; *75p+;

CitricAcid_BIN = 0; *25p-;
if 0.03 < CitricAcid <= 0.58 	then CitricAcid_BIN = 1; *IQR;
if 0.58 < CitricAcid <= 3.86 	then CitricAcid_BIN = 2; *75p+;

IMP_ResidualSugar_BIN = 0; *25p-;
if -2 < IMP_ResidualSugar <= 15.9 then IMP_ResidualSugar_BIN = 1; *IQR;
if 15.9 < IMP_ResidualSugar <= 141.15 then IMP_ResidualSugar_BIN = 2; *75p+;

IMP_Chlorides_BIN = 0; *25p-;
if -0.031 < IMP_Chlorides <= 0.153 then IMP_Chlorides_BIN = 1; *IQR;
if 0.153 < IMP_Chlorides <= 1.351 then IMP_Chlorides_BIN = 2; *75p+;

IMP_FreeSulfurDioxide_BIN = 0; *25p-;
if 0 < IMP_FreeSulfurDioxide <= 70 then IMP_FreeSulfurDioxide_BIN = 1; *IQR;
if 70 < IMP_FreeSulfurDioxide <= 623 then IMP_FreeSulfurDioxide_BIN = 2; *75p+;

IMP_TotalSulfurDioxide_BIN = 0; *25p-;
if 27 < IMP_TotalSulfurDioxide <= 208 then IMP_TotalSulfurDioxide_BIN = 1; *IQR;
if 208 < IMP_TotalSulfurDioxide <= 1057 then IMP_TotalSulfurDioxide_BIN = 2; *75p+;

Density_BIN = 0; *25p-;
if 0.98772 < Density <= 1.00052 then Density_BIN = 1; *IQR;
if 1.00052 < Density <= 1.09924 then Density_BIN = 2; *75p+;

IMP_pH_BIN = 0; *25p-;
if 2.96 < IMP_pH <= 3.47 then IMP_pH_BIN = 1; *IQR;
if 3.47 < IMP_pH <= 6.13 then IMP_pH_BIN = 2; *75p+;

IMP_Sulphates_BIN = 0; *25p-;
if 0.28 < IMP_Sulphates <= 0.86 then IMP_Sulphates_BIN = 1; *IQR;
if 0.86 < IMP_Sulphates <= 4.24 then IMP_Sulphates_BIN = 2; *75p+;

IMP_Alcohol_BIN = 0; *25p-;
if 9 < IMP_Alcohol <= 12.4 then IMP_Alcohol_BIN = 1; *IQR;
if 12.4 < IMP_Alcohol <= 26.5 then IMP_Alcohol_BIN = 2; *75p+;

* PROC REG--Kaggle Submission wine06reg;
P_REGRESSION = 3.62065
+VolatileAcidity_BIN*-0.09027
+CitricAcid_BIN*0.03814
+IMP_Chlorides_BIN*-0.03157
+IMP_FreeSulfurDioxide_BIN*0.04559
+IMP_TotalSulfurDioxide_BIN*0.06855
+IMP_pH_BIN*-0.04078
+IMP_Sulphates_BIN*-0.03493
+IMP_Alcohol_BIN*0.0506
+LabelAppeal*0.46497
+AcidIndex*-0.20442
+IMP_STARS*0.78136
+M_IMP_STARS*-2.24872
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine06nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.4978
+VolatileAcidity_BIN*-0.0289
+CitricAcid_BIN*0.0131
+IMP_Chlorides_BIN*-0.0091
+IMP_FreeSulfurDioxide_BIN*0.0159
+IMP_TotalSulfurDioxide_BIN*0.0241
+IMP_pH_BIN*-0.0148
+IMP_Sulphates_BIN*-0.013
+IMP_Alcohol_BIN*0.0122
+LabelAppeal*0.1584
+AcidIndex*-0.082
+IMP_STARS*0.1887
+M_IMP_STARS*-1.0247
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine06zip;
* PROC GENMOD ZIP;
TEMP = 1.3285
+VolatileAcidity_BIN*-0.0141
+CitricAcid_BIN*0.0063
+IMP_Chlorides_BIN*-0.0067
+IMP_FreeSulfurDioxide_BIN*0.0063
+IMP_TotalSulfurDioxide_BIN*-0.0006
+IMP_pH_BIN*-0.0007
+IMP_Sulphates_BIN*-0.0028
+IMP_Alcohol_BIN*0.0284
+LabelAppeal*0.2327
+AcidIndex*-0.0334
+IMP_STARS*0.1062
+M_IMP_STARS*-0.1828
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = 2.5005
+IMP_STARS*-4.1348
+LabelAppeal*0.7496
+M_IMP_STARS*6.2279
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine06zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.3233
+VolatileAcidity_BIN*-0.0136
+CitricAcid_BIN*0.0058
+IMP_Chlorides_BIN*-0.0062
+IMP_FreeSulfurDioxide_BIN*0.0065
+IMP_TotalSulfurDioxide_BIN*-0.0011
+IMP_pH_BIN*-0.0006
+IMP_Sulphates_BIN*-0.002
+IMP_Alcohol_BIN*0.0279
+LabelAppeal*0.2336
+AcidIndex*-0.0324
+IMP_STARS*0.1057
+M_IMP_STARS*-0.1828
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = 0.5258
+IMP_STARS*-2.2112
+LabelAppeal*0.7178
+M_IMP_STARS*4.3504
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Kaggle Submission wine06hurdle;
* Part 1;
P_LOGIT_PROB = 2.0853
+VolatileAcidity_BIN*-0.1793
+CitricAcid_BIN*0.0766
+IMP_Chlorides_BIN*-0.0136
+IMP_FreeSulfurDioxide_BIN*0.0978
+IMP_TotalSulfurDioxide_BIN*0.2495
+IMP_pH_BIN*-0.18
+IMP_Sulphates_BIN*-0.1156
+IMP_Alcohol_BIN*-0.1108
+LabelAppeal*-0.4694
+AcidIndex*-0.3966
+IMP_STARS*2.5549
+M_IMP_STARS*-4.3646
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 0.9024
+VolatileAcidity_BIN*-0.0114
+CitricAcid_BIN*0.0033
+IMP_Chlorides_BIN*-0.006
+IMP_FreeSulfurDioxide_BIN*0.0062
+IMP_TotalSulfurDioxide_BIN*-0.0106
+IMP_pH_BIN*0.0059
+IMP_Sulphates_BIN*0.0001
+IMP_Alcohol_BIN*0.0394
+LabelAppeal*0.2949
+AcidIndex*-0.0213
+IMP_STARS*0.1216
+M_IMP_STARS*-0.209
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var TARGET P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

********************************************************************;
* Model Validation Macro Code--Model 6;
********************************************************************;

%macro FIND_ERROR( DATAFILE, P, MEANVAL );

%let ERRFILE 	= ERRFILE;
%let MEANFILE	= MEANFILE;

data &ERRFILE.;
set &DATAFILE.;
	ERROR_MEAN		= abs( TARGET - &MEANVAL.)	**&P.;
	ERROR_REG		= abs( TARGET - P_REGRESSION )	**&P.;
	ERROR_NBPOI		= abs( TARGET - P_NBPOI )	**&P.;
	ERROR_ZIP		= abs( TARGET - P_ZIP )	**&P.;
	ERROR_ZINB		= abs( TARGET - P_ZINB )**&P.;
	ERROR_HURDLE	= abs( TARGET - P_HURDLE )	**&P.;
	ERROR_ENSEMBLE	= abs( TARGET - P_ENSEMBLE )**&P.;
run;

proc means data=&ERRFILE. noprint;
output out=&MEANFILE.
	mean(ERROR_MEAN)    = ERROR_MEAN
	mean(ERROR_REG)	    = ERROR_REG
	mean(ERROR_NBPOI)   = ERROR_NBPOI
	mean(ERROR_ZIP)     = ERROR_ZIP
	mean(ERROR_ZINB)    = ERROR_ZINB
	mean(ERROR_HURDLE)	= ERROR_HURDLE
	mean(ERROR_ENSEMBLE)= ERROR_ENSEMBLE
	;
run;

data &MEANFILE.;
length P 8.;
set &MEANFILE.;
	P		= &P.;
	ERROR_MEAN	= ERROR_MEAN**(1.0/&P.);
	ERROR_REG 	= ERROR_REG**(1.0/&P.);
	ERROR_NBPOI = ERROR_NBPOI**(1.0/&P.);
	ERROR_ZIP 	= ERROR_ZIP**(1.0/&P.);
	ERROR_ZINB 	= ERROR_ZINB**(1.0/&P.);
	ERROR_HURDLE 	= ERROR_HURDLE**(1.0/&P.);
	ERROR_ENSEMBLE 	= ERROR_ENSEMBLE**(1.0/&P.);
	drop _TYPE_;
run;

proc print data=&MEANFILE.;
run;

%mend;

%FIND_ERROR( DEPLOYFILE, 1	, 3.0290739 );
%FIND_ERROR( DEPLOYFILE, 2	, 3.0290739 );

********************************************************************;
* Model Scoring--Using WINE_TEST--Model 6;
********************************************************************;

%let SCORE_ME = &LIB.WINE_TEST;

* Making sure the SCORE_ME file has all 3335 records--it does;
proc means data=&SCORE_ME. n;
var INDEX;
run;

data DEPLOYFILE;
set &SCORE_ME.;

title "Model 6";

IMP_ResidualSugar = ResidualSugar;
M_IMP_ResidualSugar = missing(IMP_ResidualSugar);
if IMP_ResidualSugar = . then IMP_ResidualSugar = 5.4187331; * mean;

IMP_Chlorides = Chlorides;
M_IMP_Chlorides = missing(IMP_Chlorides);
if IMP_Chlorides = . then IMP_Chlorides = 0.0548225; * mean;

IMP_FreeSulfurDioxide = FreeSulfurDioxide;
M_IMP_FreeSulfurDioxide = missing(IMP_FreeSulfurDioxide);
if IMP_FreeSulfurDioxide = . then IMP_FreeSulfurDioxide = 30.8455713; * mean;

IMP_TotalSulfurDioxide = TotalSulfurDioxide;
M_IMP_TotalSulfurDioxide = missing(IMP_TotalSulfurDioxide);
if IMP_TotalSulfurDioxide = . then IMP_TotalSulfurDioxide = 120.7142326; * mean;

IMP_pH = pH;
M_IMP_pH = missing(IMP_pH);
if IMP_pH = . then IMP_pH = 3.2; * median;

IMP_Sulphates = Sulphates;
M_IMP_Sulphates = missing(IMP_Sulphates);
if IMP_Sulphates = . then IMP_Sulphates = 0.5; * median;

IMP_Alcohol = Alcohol;
M_IMP_Alcohol = missing(IMP_Alcohol);
if IMP_Alcohol = . then IMP_Alcohol = 10.4; * median;

IMP_STARS = STARS;
M_IMP_STARS = missing(IMP_STARS);
if IMP_STARS = . then IMP_STARS = 2; * mean/median;

FixedAcidity_BIN = 0; *25p-;
if 5.2 < FixedAcidity <= 9.5 	then FixedAcidity_BIN = 1; *IQR;
if 9.5 < FixedAcidity <= 34.4 	then FixedAcidity_BIN = 2; *75p+;

VolatileAcidity_BIN = 0; *25p-;
if 0.13 < VolatileAcidity <= 0.64 	then VolatileAcidity_BIN = 1; *IQR;
if 0.64 < VolatileAcidity <= 3.68 	then VolatileAcidity_BIN = 2; *75p+;

CitricAcid_BIN = 0; *25p-;
if 0.03 < CitricAcid <= 0.58 	then CitricAcid_BIN = 1; *IQR;
if 0.58 < CitricAcid <= 3.86 	then CitricAcid_BIN = 2; *75p+;

IMP_ResidualSugar_BIN = 0; *25p-;
if -2 < IMP_ResidualSugar <= 15.9 then IMP_ResidualSugar_BIN = 1; *IQR;
if 15.9 < IMP_ResidualSugar <= 141.15 then IMP_ResidualSugar_BIN = 2; *75p+;

IMP_Chlorides_BIN = 0; *25p-;
if -0.031 < IMP_Chlorides <= 0.153 then IMP_Chlorides_BIN = 1; *IQR;
if 0.153 < IMP_Chlorides <= 1.351 then IMP_Chlorides_BIN = 2; *75p+;

IMP_FreeSulfurDioxide_BIN = 0; *25p-;
if 0 < IMP_FreeSulfurDioxide <= 70 then IMP_FreeSulfurDioxide_BIN = 1; *IQR;
if 70 < IMP_FreeSulfurDioxide <= 623 then IMP_FreeSulfurDioxide_BIN = 2; *75p+;

IMP_TotalSulfurDioxide_BIN = 0; *25p-;
if 27 < IMP_TotalSulfurDioxide <= 208 then IMP_TotalSulfurDioxide_BIN = 1; *IQR;
if 208 < IMP_TotalSulfurDioxide <= 1057 then IMP_TotalSulfurDioxide_BIN = 2; *75p+;

Density_BIN = 0; *25p-;
if 0.98772 < Density <= 1.00052 then Density_BIN = 1; *IQR;
if 1.00052 < Density <= 1.09924 then Density_BIN = 2; *75p+;

IMP_pH_BIN = 0; *25p-;
if 2.96 < IMP_pH <= 3.47 then IMP_pH_BIN = 1; *IQR;
if 3.47 < IMP_pH <= 6.13 then IMP_pH_BIN = 2; *75p+;

IMP_Sulphates_BIN = 0; *25p-;
if 0.28 < IMP_Sulphates <= 0.86 then IMP_Sulphates_BIN = 1; *IQR;
if 0.86 < IMP_Sulphates <= 4.24 then IMP_Sulphates_BIN = 2; *75p+;

IMP_Alcohol_BIN = 0; *25p-;
if 9 < IMP_Alcohol <= 12.4 then IMP_Alcohol_BIN = 1; *IQR;
if 12.4 < IMP_Alcohol <= 26.5 then IMP_Alcohol_BIN = 2; *75p+;

* PROC REG--Kaggle Submission wine06reg;
P_REGRESSION = 3.62065
+VolatileAcidity_BIN*-0.09027
+CitricAcid_BIN*0.03814
+IMP_Chlorides_BIN*-0.03157
+IMP_FreeSulfurDioxide_BIN*0.04559
+IMP_TotalSulfurDioxide_BIN*0.06855
+IMP_pH_BIN*-0.04078
+IMP_Sulphates_BIN*-0.03493
+IMP_Alcohol_BIN*0.0506
+LabelAppeal*0.46497
+AcidIndex*-0.20442
+IMP_STARS*0.78136
+M_IMP_STARS*-2.24872
;
if P_REGRESSION < 0 then P_REGRESSION = 0; * only necessary for PROC REG;
********************************************************************;
* Kaggle Submission wine06nbpoi;
* PROC GENMOD NB and POI (same equation);
TEMP = 1.4978
+VolatileAcidity_BIN*-0.0289
+CitricAcid_BIN*0.0131
+IMP_Chlorides_BIN*-0.0091
+IMP_FreeSulfurDioxide_BIN*0.0159
+IMP_TotalSulfurDioxide_BIN*0.0241
+IMP_pH_BIN*-0.0148
+IMP_Sulphates_BIN*-0.013
+IMP_Alcohol_BIN*0.0122
+LabelAppeal*0.1584
+AcidIndex*-0.082
+IMP_STARS*0.1887
+M_IMP_STARS*-1.0247
;

P_NBPOI = exp(TEMP);
drop TEMP;

* This shows that TARGET, X_GENMOD_POI, and P_TARGET are all similar, as they should be;
*For this to work, you must do: data DEPLOYFILE; *set &FIXFILE.;
*proc print data=DEPLOYFILE(obs=10);
*var TARGET X_GENMOD_POI P_TARGET;
*run;
********************************************************************;
* Kaggle Submission wine06zip;
* PROC GENMOD ZIP;
TEMP = 1.3285
+VolatileAcidity_BIN*-0.0141
+CitricAcid_BIN*0.0063
+IMP_Chlorides_BIN*-0.0067
+IMP_FreeSulfurDioxide_BIN*0.0063
+IMP_TotalSulfurDioxide_BIN*-0.0006
+IMP_pH_BIN*-0.0007
+IMP_Sulphates_BIN*-0.0028
+IMP_Alcohol_BIN*0.0284
+LabelAppeal*0.2327
+AcidIndex*-0.0334
+IMP_STARS*0.1062
+M_IMP_STARS*-0.1828
;
P_SCORE_ZIP_ALL = exp( TEMP );

TEMP = 2.5005
+IMP_STARS*-4.1348
+LabelAppeal*0.7496
+M_IMP_STARS*6.2279
;
P_SCORE_ZERO = exp(TEMP)/(1+exp(TEMP));

P_ZIP = P_SCORE_ZIP_ALL * (1-P_SCORE_ZERO);
********************************************************************;
* Kaggle Submission wine06zinb;
* PROC GENMOD ZINB;
TEMP2 = 1.3233
+VolatileAcidity_BIN*-0.0136
+CitricAcid_BIN*0.0058
+IMP_Chlorides_BIN*-0.0062
+IMP_FreeSulfurDioxide_BIN*0.0065
+IMP_TotalSulfurDioxide_BIN*-0.0011
+IMP_pH_BIN*-0.0006
+IMP_Sulphates_BIN*-0.002
+IMP_Alcohol_BIN*0.0279
+LabelAppeal*0.2336
+AcidIndex*-0.0324
+IMP_STARS*0.1057
+M_IMP_STARS*-0.1828
;
P_SCORE_ZINB_ALL = exp( TEMP2 );

TEMP2 = 0.5258
+IMP_STARS*-2.2112
+LabelAppeal*0.7178
+M_IMP_STARS*4.3504
;
P_SCORE_ZERO2 = exp(TEMP2)/(1+exp(TEMP2));

P_ZINB = P_SCORE_ZINB_ALL * (1-P_SCORE_ZERO2);
********************************************************************;
* Bingo Bonus PROC LOGISTIC/POISSON model;
* Kaggle Submission wine06hurdle;
* Part 1;
P_LOGIT_PROB = 2.0853
+VolatileAcidity_BIN*-0.1793
+CitricAcid_BIN*0.0766
+IMP_Chlorides_BIN*-0.0136
+IMP_FreeSulfurDioxide_BIN*0.0978
+IMP_TotalSulfurDioxide_BIN*0.2495
+IMP_pH_BIN*-0.18
+IMP_Sulphates_BIN*-0.1156
+IMP_Alcohol_BIN*-0.1108
+LabelAppeal*-0.4694
+AcidIndex*-0.3966
+IMP_STARS*2.5549
+M_IMP_STARS*-4.3646
;
if P_LOGIT_PROB > 1000 then P_LOGIT_PROB = 1000;
if P_LOGIT_PROB < -1000 then P_LOGIT_PROB = -1000;
P_LOGIT_PROB = exp(P_LOGIT_PROB) / (1+exp(P_LOGIT_PROB));

* Part 2;	
P_GENMOD_HURDLE = 0.9024
+VolatileAcidity_BIN*-0.0114
+CitricAcid_BIN*0.0033
+IMP_Chlorides_BIN*-0.006
+IMP_FreeSulfurDioxide_BIN*0.0062
+IMP_TotalSulfurDioxide_BIN*-0.0106
+IMP_pH_BIN*0.0059
+IMP_Sulphates_BIN*0.0001
+IMP_Alcohol_BIN*0.0394
+LabelAppeal*0.2949
+AcidIndex*-0.0213
+IMP_STARS*0.1216
+M_IMP_STARS*-0.209
;
P_GENMOD_HURDLE = exp(P_GENMOD_HURDLE);

P_HURDLE = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;
*run;
********************************************************************;
* To create an ensemble model, put all the predicted values from the equations together;

P_ENSEMBLE = (P_REGRESSION + P_NBPOI + P_ZIP + P_ZINB + P_HURDLE)/5;

*keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

data DEPLOYFILE_ROUNDED;
set DEPLOYFILE;

P_REGRESSION 	= round(P_REGRESSION, 1);
P_NBPOI 		= round(P_NBPOI, 1);
P_ZIP			= round(P_ZIP, 1);
P_ZINB			= round(P_ZINB, 1);
P_HURDLE 		= round(P_HURDLE, 1);
P_ENSEMBLE		= round(P_ENSEMBLE, 1);

run;

proc print data=DEPLOYFILE_ROUNDED(obs=10);
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

proc means data=DEPLOYFILE_ROUNDED sum;
var P_REGRESSION P_NBPOI P_ZIP P_ZINB P_HURDLE P_ENSEMBLE;
run;

*proc means data=DEPLOYFILE;
*var P_TARGET;
*run;

********************************************************************;
* Exporting the Scored Model--Model 6;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/wine06reg.csv'
   dbms=csv
   replace;
*run;