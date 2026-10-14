/* AUTHOR: EMANUELE GUIDOTTI

    This SAS code matches trades with the NBBO quotes from the Daily TAQ database 
    to compute effective spreads using the midpoint (Holden and Jacobsen, 2014), 
    or the weighted midpoint (Hagstromer, 2021) as the reference price.
    
    The output is a CSV file structured as follows:
    ---------------------------------------------------
    |    DATE    |    SYMBOL    |    QM    |    QW    |
    ---------------------------------------------------
    |            |              |          |          | 
    ---------------------------------------------------
    
    Variable definitions:
        * DATE      Date in the format YYYYMMDD
        * SYMBOL    The TAQ trading symbol
        * QM        Effective spread computed using the quoted midpoint as in Holden and Jacobsen (2014)
        * QW        Effective spread computed using the quoted weighted-midpoint as in Hagstromer (2021)
    
    Usage:
        sas quotes.sas -set quotes [quotes] -set trades [trades] -set outfile [outfile]

    Arguments:
        * quotes: the path to the Daily TAQ NBBO quote file
        * trades: the path to the corresponding Daily TAQ trade file
        * outfile: the name of the output file. This is a compressed csv file. It should end with .csv.gz

    Example:
        sas quotes.sas \
            -set quotes "/wrds/nyse/sasdata/wrds_taqms_nbbo/complete_nbbo_20091014.sas7bdat" \
            -set trades "/wrds/nyse/sasdata/taqms/ct/ctm_20091014.sas7bdat" \
            -set outfile "filename.csv.gz"

*/


/* STEP 1: Read command line arguments */
    %let quotes = %sysget(quotes);
    %let trades = %sysget(trades);
    %let outfile = %sysget(outfile);


/* STEP 2: Load trade data between 9:30-16:00 */
    data trades;
        set "&trades";
        where "9:30:00"t <= TIME_M <= "16:00:00"t and PRICE > 0 and TR_CORR = "00" and SYM_SUFFIX = '';
        keep SYM_ROOT DATE TIME_M PRICE;
        rename SYM_ROOT=SYMBOL TIME_M=TIME;
    run;


/* STEP 3: Load quote data between 9:00-16:00 and compute midpoints */
    data quotes;    
        set "&quotes";
        where "9:00:00"t <= TIME_M <= "16:00:00"t and SYM_SUFFIX = '';
        MID = (BEST_ASK + BEST_BID) / 2;
        WMD = (BEST_ASK * Best_BidSizeShares + BEST_BID * Best_AskSizeShares) / (Best_BidSizeShares + Best_AskSizeShares);
        VALID = (QU_COND = "R" and 0.01 < BEST_BID < BEST_ASK and Best_BidSizeShares > 0 and Best_AskSizeShares > 0);
        keep SYM_ROOT DATE TIME_M MID WMD VALID;
        rename SYM_ROOT=SYMBOL TIME_M=TIME;
    run;


/* STEP 4: Compute start and end times for each quote */
    data quotes;
        set quotes;
        by SYMBOL;
        M1 = lag(MID);
        W1 = lag(WMD);
        T1 = lag(TIME); 
        V1 = lag(VALID);
        if V1 and not first.SYMBOL;
        keep DATE SYMBOL M1 W1 T1 TIME;
        rename DATE=Q_DATE SYMBOL=Q_SYMBOL M1=MID W1=WMD T1=TIME_START TIME=TIME_END;
    run;


/* STEP 5: Merge trades with last quote */
    data merged;
        set trades;
        retain n 1;
        if n <= nobs then do i=n to nobs;
            set quotes nobs=nobs point=i; n = i;
            if Q_SYMBOL>SYMBOL or (Q_SYMBOL=SYMBOL and TIME_START>TIME) then leave;
            if Q_DATE=DATE and Q_SYMBOL=SYMBOL and TIME_START < TIME <= TIME_END then do;
                output;
                leave;
            end;
        end;
    run;


/* STEP 6: Lee, Ready (1991) trade classification */
    data merged;
        set merged;
        by SYMBOL;
        P1 = lag(PRICE); if first.SYMBOL then P1=.;
        D1 = lag(D); if first.SYMBOL then D1=.; 
        if PRICE > MID then D = +1; 
        else if PRICE < MID then D = -1; 
        else if PRICE > P1 or (PRICE = P1 and D1 = +1) then D = +1;
        else if PRICE < P1 or (PRICE = P1 and D1 = -1) then D = -1;
        else D=.;
    run;


/* STEP 7: Compute effective spreads */   
    proc sql;
        CREATE TABLE spreads AS
        SELECT 
            DATE AS DATE, 
            SYMBOL AS SYMBOL, 
            AVG(2 * D * (PRICE - MID) / MID) AS QM,
            AVG(2 * D * (PRICE - WMD) / MID) AS QW
        FROM
            merged
        GROUP BY
            DATE,
            SYMBOL;
    quit;


/* STEP 8: Export to compressed csv file */
filename outfile zip "&outfile" gzip;
data spreads; set spreads; format DATE yymmddn8.; run;
proc export data=spreads outfile=outfile dbms=csv replace; run;
