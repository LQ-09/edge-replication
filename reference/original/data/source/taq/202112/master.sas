/* AUTHOR: EMANUELE GUIDOTTI

    This SAS code downloads effective spreads in 1993-2021 from WRDS Intraday 
    Indicators and merges the CUSIP identifiers from the TAQ Master Files. 
    The CUSIP identifier can be used to match other databases (e.g., CRSP).
    
    The output is a CSV file structured as follows:
    -----------------------------------------------------------
    |   DATE   |   SYMBOL   |   CUSIP   |   HJ   |   NUMTRD   |
    -----------------------------------------------------------
    |          |            |           |        |            |
    -----------------------------------------------------------
    
    Variable definitions:
        * DATE      Date in the format YYYYMMDD
        * SYMBOL    The TAQ trading symbol
        * CUSIP     CUSIP code (9 digits)
        * HJ        Simple averaged percent effective spread as described in Holden and Jacobsen (2014)
        * NUMTRD    Total number of trades during market hours
    
    The effective spreads are pre-computed by WRDS according to the methodology
    described in: Holden, C. and S. Jacobsen, 2014, Liquidity Measurement 
    Problems in Fast, Competitive Markets: Expensive and Cheap Solutions,
    Journal of Finance 69, 1747-1785.
    
    This code downloads spreads derived from:
        * 1993-2003: TAQ Monthly Database
        * 2004-2021: TAQ Daily Database
    and CUSIP codes obtained from:
        * 1993-2009: TAQ Monthly Database
        * 2010-2021: TAQ Daily Database

    See https://wrds-www.wharton.upenn.edu/pages/get-data/intraday-indicators-wrds/ 
*/


/* STEP 1: Path to WRDS indicators and TAQ master files */
    libname mast '/wrds/nyse/sasdata/taqs';
    libname mastm '/wrds/nyse/sasdata/taqms/mast';
    libname iid '/wrds/nyse/sasdata/wrds_taqs_iid_v1';
    libname iidm '/wrds/nyse/sasdata/wrds_taqms_iid';   


/* STEP 2: Retrieve effective spreads from Monthly TAQ */
    data iid;
        set iid.wrds_iid_1993-iid.wrds_iid_2003;
        keep SYMBOL DATE ESpreadPct_Avg1 NumTrades_m;
        rename ESpreadPct_Avg1=ES NumTrades_m=NUMTRD;  
    run;


/* STEP 3: Retrieve effective spreads from Daily TAQ */
    data iidm;
        set iidm.wrds_iid_2004-iidm.wrds_iid_2021;
        where SYM_SUFFIX = ''; 
        keep SYMBOL DATE EffectiveSpread_Percent_Ave total_n_trades_m;
        rename EffectiveSpread_Percent_Ave=ES total_n_trades_m=NUMTRD;  
    run;
    

/* STEP 4: Create the full dataset of effective spreads */
    data spreads;
        set iid iidm;
    run;


/* STEP 5: Retrieve cusip codes from Monthly TAQ master files */
    data mast;
        set mast.mast_1993: mast.mast_1994: mast.mast_1995: mast.mast_1996: mast.mast_1997: mast.mast_1998: mast.mast_1999: mast.mast_2000: mast.mast_2001: mast.mast_2002: mast.mast_2003: mast.mast_2004: mast.mast_2005: mast.mast_2006: mast.mast_2007: mast.mast_2008: mast.mast_2009:;
        VALID = (length(CUSIP)=12 and substr(CUSIP, 10, 1)='0' and TYPE=0);
        CUSIP = substr(CUSIP, 1, 9);
        keep SYMBOL FDATE CUSIP VALID;
        rename FDATE=DATE;
    run;


/* STEP 6: Retrieve cusip codes from Daily TAQ master files */
    data mastm;
        set mastm.mastm_2010: mastm.mastm_2011: mastm.mastm_2012: mastm.mastm_2013: mastm.mastm_2014: mastm.mastm_2015: mastm.mastm_2016: mastm.mastm_2017: mastm.mastm_2018: mastm.mastm_2019: mastm.mastm_2020: mastm.mastm_2021: ;
        VALID = (SEC_TYPE='A' or SEC_TYPE='');
        keep SYMBOL_15 DATE CUSIP VALID;
        rename SYMBOL_15=SYMBOL;
    run;


/* STEP 7: Create the full dataset of cusip codes */
    data cusip;
        length SYMBOL $ 15;
        set mast mastm;
        where not missing(DATE);
        VALID = (VALID and length(CUSIP)=9 and CUSIP^="000000000");
    run;


/* STEP 8: Sort each symbol by descending date and drop duplicates */
    proc sort data=cusip out=cusip nodupkey;
        by SYMBOL descending DATE CUSIP; 
    run;


/* STEP 9: Find the end date for each begin date of cusip codes, or set it to: 01 Jan 2050 */
    data cusip;
        set cusip;
        by SYMBOL;
        DATE_END = lag(DATE);
        if first.SYMBOL then DATE_END = '01JAN2050'd;
        if VALID;
    run;
    

/* STEP 10: Merge spreads with cusip codes */
    proc sql;
        CREATE TABLE master AS
        SELECT 
            s.DATE AS DATE, 
            s.SYMBOL AS SYMBOL, 
            c.CUSIP AS CUSIP,
            s.ES AS HJ,
            s.NUMTRD AS NUMTRD
        FROM
            spreads AS s, 
            cusip AS c
        WHERE
            s.SYMBOL = c.SYMBOL AND
            s.DATE >= c.DATE AND s.DATE < c.DATE_END AND
            s.ES > 0
        ORDER BY
            s.DATE,
            s.SYMBOL;
    quit;


/* STEP 11: Export to compressed csv file */
filename outfile zip "master.csv.gz" gzip;
data master; set master; format DATE yymmddn8.; run;
proc export data=master outfile=outfile dbms=csv replace; run;
