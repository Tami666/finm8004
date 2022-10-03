/////DATA FILES REQUIRED TO RUN THE DO FILE////
*[1] raw_sample_90_10 /// all firms listed in Compustat from 1990 to 2010, with no null values for AT, DVC PRCC_F, CSHO
*[2] cstat_initial_sample_89_10 /// using the GVKEY distinct file, rerun initial sample search for from FY1989 to obtain prior years' data for lagged calcs.
*[3] crsp_dividends_89_10 /// sample of firms' dividend data from CRSP-Compustat merged database from 1989 to 2010. Use distinct GVKEY file to obtain      
*[4] compustat_firstdate_all /// cleaned list of all firms on Compustat to 2010 with the date they first appeared in the database for "firm age" calculations
***** need to change the file directory to your own local drive, currently set to C:\Users\X1 Nat\OneDrive - Australian National University\Desktop\ANU\Semester 2 - 2022\FINM8004 - Advanced Corporate Finance\Assignments\Replication Project\Data\Audit\******

****save all files with the exact file names above***

*****Startup code****
cd "C:\Users\tamiz\OneDrive - Australian National University\ANU\FINM8004\Replication project\Redo"
pwd


***Start cleaning ***
clear
use raw_sample_90_10
destring gvkey, replace
destring sic, replace
drop if inrange(sic, 4900, 4949)
drop if inrange(sic, 6000, 6999)
duplicates report gvkey fyear
save gvkey_distinct, replace
**obtain unique GVKEY of initial sample of firms (~16,000)**

**use distinct GVKEY file file to obtain 1989 values and CRSP dividend data***
clear
use gvkey_distinct
egen tag = tag(gvkey)
list gvkey if tag 
keep if tag 
keep gvkey
save gvkey_distinct, replace

**Clean Compustat sample data***
clear
use cstat_initial_sample_89_10
drop indfmt consol popsrc datafmt curcd costat
generate process=1
gen dyear=year(datadate)
destring gvkey, replace
order gvkey dyear fyear datadate at dvc csho prcc_f prstkc pstkrv ni xrd capx dltt dlc oibdp che ceq txdb
label variable process "Original Data File"
duplicates report gvkey fyear

**duplicates all good***

save cstat_cleaned, replace

***clean CRSP data***
use crsp_dividends_89_10
rename GVKEY gvkey
destring gvkey, replace
duplicates report gvkey fyear
bys gvkey fyear: gen n=_N
generate process=3
***manual inspection, loads of unnecessary duplicates****
duplicates drop gvkey fyear, force

**remove all unnecessary data premerge**
drop datadate indfmt consol popsrc datafmt curcd dvp dvpd costat n
rename dvc dvc_crsp
label variable dvc_crsp "CRSP dividends"
sort gvkey fyear
save crsp_clean, replace

/////CRSP dividend data merge//////
***merge initial dataset with CRSP dividend data***
clear
use cstat_cleaned, clear
sort gvkey fyear
save cstat_cleaned, replace
merge 1:1 gvkey fyear using crsp_clean
keep if _merge==1 | _merge==3
drop _merge
order gvkey dyear fyear datadate at dvc_crsp
save crsp_cstat_merged, replace

***years in Compustat merge****
clear
use compustat_firstdate_all
sort gvkey
save compustat_firstdate_all, replace

***merge with firstdate data to generate new first date for each GVKEY***
clear
use crsp_cstat_merged, clear
sort gvkey
merge m:1 gvkey using compustat_firstdate_all
keep if _merge == 3
drop _merge
label variable firstdate "Date first appearing in Compustat"
save crsp_cstat_merged, replace

***declare panel data and state that it is ordered by financial year***
xtset gvkey fyear
save crsp_cstat_merged, replace

////VARIABLE CALCULATIONS////

///Pre calculations///
***Zero missing values from DVC + R&D***
replace dvc_crsp = 0 if missing(dvc_crsp) 
replace xrd = 0 if missing(xrd)

***Repurchases***
gen repurch = cond((prstkc-pstkrv)/(L.csho*L.prcc_f)>0.01,prstkc-pstkrv,0)
replace repurch = 0 if missing(repurch)
	
***Total Payout ***
gen totpay = repurch + dvc_crsp
gen totpayat = totpay/at

///Variables in alphabetical order ///
***CapEx/LagTA***
gen capexLta = capx/L.at

***Cash/TA***
gen cashta = che/at

***Cash flow/Lag***
gen cashlta = oibdp/L.at

**Cash flow volatility****///Mahek

**Cash savings from payout*** 
tssmooth ma prevpay = totpay, window(2)
gen csfpay = (prevpay - totpay)/L.at

***Dividends dvc_crsp***
///already in data set

***Financial Crisis***
#delim ;
gen fcrisis = cond(fyear==2008, 1,
			  cond(fyear==2009, 1, 0));
			  #delim cr
			  
***Firm Age***
gen age = fyear - firstdate
keep if age>=0
label variable age "Company Compustat age"

***Log(assets)
///ln(at)

***Losses*** // Need to examine this one very closely
gen dloss = cond(ni<0, 1, 0)
bys gvkey: gen losses = L.dloss + L2.dloss + L3.dloss + L4.dloss + L5.dloss

***Market Leverage***
gen mktlev = (dltt + dlc)/(prcc_f*csho)

***Payout Reduction*** 
gen poredd = cond(totpay - L.totpay<0, 1, 0)
gen payred = cond(L.poredd==1, 1, 0)

***(R&D+CapEx)/TA***
gen randcapexta = (xrd+capx)/at   

***Tobin's Q***
gen mktva = (at + (csho*prcc_f) - ceq - txdb)
gen tobq = mktva/((0.1*mktva) + (0.9*at))

***Volatility***///Mahek

keep if fyear>1989
save dataset_calculations, replace
save regression_tab3_main, replace
save regression_tab3_robust, replace
save regression_tab6_main, replace

*-------------------------------------------------------------------
* Table 3 Logit regression of payout reduction *
gen fcrisis_mktlev=fcrisis*mktlev
gen fcrisis_cashta=fcrisis*cashta
gen fcrisis_tobq=fcrisis*tobq
gen fcrisis_cashlta=fcrisis*cashlta
gen fcrisis_randcapexta=fcrisis*randcape

gen C = . // group
replace C = 1 if fyear>=1999&fyear<=2003 //recession 
replace C = 2 if fyear>=2005&fyear<=2009 //finanical cirsis

