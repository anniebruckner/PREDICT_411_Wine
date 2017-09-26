* Andrea Bruckner
  PREDICT 411, Sec 55
  Spring 2016
  Unit 03: Wine Stand Alone Score File
;

********************************************************************;
* Preliminary Steps;
********************************************************************;

* Access library where data sets are stored;

%let PATH = /folders/myfolders/PREDICT_411/Wine;
%let NAME = POI;
%let LIB = &NAME..;
%let INFILE = &LIB.WINE;

%let TEMPFILE = TEMPFILE;
%let FIXFILE = FIXFILE;

libname &NAME. "&PATH.";

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

title "Model 6 Hurdle";

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

* PROC LOGISTIC/POISSON model;
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

P_TARGET = P_LOGIT_PROB * (P_GENMOD_HURDLE+1); * ties Parts 1 and 2 together;

keep INDEX P_TARGET;

run;

proc print data=DEPLOYFILE(obs=10);
run;

********************************************************************;
* Exporting the Scored Model--Model 6 Hurdle;
********************************************************************;

* Remove the comments to activate + change csv file name for each model;
*proc export data=DEPLOYFILE
   outfile='/folders/myfolders/PREDICT_411/Wine/BrucknerBestWine.csv'
   dbms=csv
   replace;
*run;