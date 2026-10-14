/* AUTHOR: EMANUELE GUIDOTTI

    This SAS code aggregates a TAQ trade file into open, high, low, and close prices
    and estimates effective spreads with several methods.
    
    The output is a CSV file structured as follows:
    ---------------------------------------------
    | DATE | SYMBOL | EDGE |  AR  | CS |  ROLL  |
    ---------------------------------------------
    |      |        |      |      |    |        |
    ---------------------------------------------
    
    Variable definitions:
        * DATE      Date in the format YYYYMMDD
        * SYMBOL    The TAQ trading symbol
        * EDGE      Spread estimate as in Ardia, Guidotti, & Kroencke (2021)
        * AR        Spread estimate as in Abdi & Ranaldo (2017)
        * CS        Spread estimate as in Corwin & Schultz (2012)
        * ROLL      Spread estimate as in Roll (1984)
    
    Note:
        Spread estimates are signed
    
    Usage:
        sas trades.sas -set trades [trades] -set freq [freq] -set outfile [outfile]

    Arguments:
        * trades: the path to the TAQ trade file. Supports both Monthly TAQ and Daily TAQ
        * freq: the frequency of the OHLC prices in SAS time intervals. E.g., "minute1" for 1-minute intervals
        * outfile: the name of the output file. This is a compressed csv file. It should end with .csv.gz

    Example:
        sas trades.sas \
            -set trades "/wrds/nyse/sasdata/taqms/ct/ctm_20091014.sas7bdat" \
            -set freq "minute1" \
            -set outfile "filename.csv.gz"

*/


/* STEP 1: Read command line arguments */
    %let trades = %sysget(trades);
    %let freq = %sysget(freq);
    %let outfile = %sysget(outfile);


/* STEP 2: Check whether this is a Monthly TAQ or Daily TAQ file */
    %let dsid = %sysfunc(open(&trades,,,F));
    %let taqms = %sysfunc(varnum(&dsid, TIME_M));
    %let rc = %sysfunc(close(&dsid));


/* STEP 3: Set variables conditional on whether this is a Monthly TAQ or Daily TAQ file */
    %let time = %sysfunc(ifc(&taqms, TIME_M, TIME));
    %let symbol = %sysfunc(ifc(&taqms, SYM_ROOT, SYMBOL));
    %let where = %sysfunc(ifc(
        &taqms, 
        "9:30:00"t <= TIME_M <= "16:00:00"t and PRICE > 0 and TR_CORR = "00" and SYM_SUFFIX = '',
        "9:30:00"t <= TIME <= "16:00:00"t and PRICE > 0 and CORR = 0
    ));


/* STEP 4: Load trades and round timestamps */
    data trades;
        set "&trades";
        where &where;
        TIME = intnx("&freq", &time, 0);
        keep &symbol DATE TIME PRICE;
        rename &symbol=SYMBOL;
    run;


/* STEP 5: Aggregate trades into open, high, low, and close prices */
    data ohlc;

        set trades;
        by SYMBOL TIME;
        retain OPEN HIGH LOW CLOSE;
        
        TIME_PREV = lag1(TIME);
        if first.TIME and not first.SYMBOL then 
            do;
                TIME_NEXT = intnx("&freq", TIME_PREV, 1); 
                do while(TIME_NEXT < TIME);
                    output;
                    TIME_NEXT = intnx("&freq", TIME_NEXT, 1);
                end;
            end;

        if first.TIME then 
            do;
                OPEN = PRICE;
                HIGH = PRICE;
                LOW = PRICE;
            end;
        
        if PRICE > HIGH then 
            do;
                HIGH = PRICE;
            end;

        if PRICE < LOW then
            do; 
                LOW = PRICE;
            end;
        
        if last.TIME then 
            do;
                CLOSE = PRICE;
                output;
            end;

        keep DATE SYMBOL OPEN HIGH LOW CLOSE;

    run;


/* STEP 6: Define variables */
    data vars;

        set ohlc;
        by SYMBOL;

        o = log(OPEN);
        h = log(HIGH);
        l = log(LOW);
        c = log(CLOSE);
        m = (h + l) / 2;

        h1 = lag1(h);
        l1 = lag1(l);    
        m1 = lag1(m);
        c1 = lag1(c);
        c2 = lag2(c);

        r1 = m-o;
        r2 = o-m1;
        r3 = m-c1;
        r4 = c1-m1;
        r5 = o-c1;

        tau = h ne l | l ne c1;
        phi1 = o ne h & tau;
        phi2 = o ne l & tau;
        phi3 = c1 ne h1 & tau;
        phi4 = c1 ne l1 & tau;

        b = (h-l)**2 + (h1-l1)**2;
        g = (MAX(h, h1) - MIN(l, l1))**2;
        a = (SQRT(2*b) - SQRT(b)) / (3 - 2*SQRT(2)) - SQRT(g / (3 - 2*SQRT(2)));
        cs = 2 * (EXP(a) - 1) / (1 + EXP(a));
        
        if SYMBOL eq lag2(SYMBOL) then 
            do;
                rc1 = c-c1;
                rc2 = c1-c2;
            end;
        else 
            do;
                rc1 = .;
                rc2 = .;
            end;
        
        if not first.SYMBOL;

    run;


/* STEP 7: Compute averages */
    proc sql;

        CREATE TABLE avg AS
        
        SELECT 
            DATE,
            SYMBOL,
            COUNT(*)          AS n,
            AVG(r1*r2)        AS m1,
            AVG(r3*r4)        AS m2,
            AVG(r1*r5)        AS m3,
            AVG(r5*r4)        AS m4,
            AVG(tau)          AS m5,
            AVG(r1)           AS m6,
            AVG(tau*r2)       AS m7,
            AVG(r3)           AS m8,
            AVG(tau*r4)       AS m9,
            AVG(r5)           AS m10,
            AVG(r1**2*r2**2)  AS m11,
            AVG(r3**2*r4**2)  AS m12,
            AVG(r1**2*r5**2)  AS m13,
            AVG(r4**2*r5**2)  AS m14,
            AVG(r1*r2*r3*r4)  AS m15,
            AVG(r1*r4*r5**2)  AS m16,
            AVG(tau*r2**2)    AS m17,
            AVG(tau*r4**2)    AS m18,
            AVG(tau*r5**2)    AS m19,
            AVG(tau*r1*r2**2) AS m20,
            AVG(tau*r3*r4**2) AS m21,
            AVG(tau*r1*r5**2) AS m22,
            AVG(tau*r5*r4**2) AS m23,
            AVG(tau*r1*r2*r4) AS m24,
            AVG(tau*r2*r3*r4) AS m25,
            AVG(tau*r2*r4)    AS m26,
            AVG(tau*r1*r4*r5) AS m27,
            AVG(tau*r4*r5**2) AS m28,
            AVG(tau*r4*r5)    AS m29,
            AVG(tau*r5)       AS m30,
            AVG(phi1)         AS m31,
            AVG(phi2)         AS m32,
            AVG(phi3)         AS m33,
            AVG(phi4)         AS m34,
            AVG(cs)           AS m35,
            AVG(rc1)          AS m36,
            AVG(rc2)          AS m37,
            AVG(rc1*rc2)      AS m38

        FROM
            vars
                
        GROUP BY
            DATE,
            SYMBOL;

    quit;


/* STEP 8: Compute spreads */
    data spreads;

        set avg;

        po = -8 / (m31 + m32);
        pc = -8 / (m33 + m34);
        
        e1 = po/2 * (m1 - m6*m7/m5) + 
            pc/2 * (m2 - m8*m9/m5);
        
        e2 = po/2 * (m3 - m6*m30/m5) + 
            pc/2 * (m4 - m10*m9/m5);
        
        v1 = po**2/4 * (m11 + m6**2*m17/m5**2 - 2*m20*m6/m5) +
            pc**2/4 * (m12 + m8**2*m18/m5**2 - 2*m21*m8/m5) +
            po*pc/2 * (m15 - m24*m8/m5 - m6*m25/m5 + m6*m8*m26/m5**2) - 
            e1**2;
        
        v2 = po**2/4 * (m13 + m6**2*m19/m5**2 - 2*m22*m6/m5) +
            pc**2/4 * (m14 + m10**2*m18/m5**2 - 2*m23*m10/m5) +
            po*pc/2 * (m16 - m27*m10/m5 - m6*m28/m5 + m6*m10*m29/m5**2) -
            e2**2;
        
        EDGE = (v2*e1 + v1*e2) / (v1 + v2);
        EDGE = SIGN(EDGE) * SQRT(ABS(EDGE));

        AR = -4 * m2;
        AR = SIGN(AR) * SQRT(ABS(AR));

        CS = m35;

        ROLL = -4 * (n-1)/(n-2) * (m38 - m36*m37);
        ROLL = SIGN(ROLL) * SQRT(ABS(ROLL));

        keep DATE SYMBOL EDGE AR CS ROLL;

    run;

/* STEP 9: Export to compressed csv file */
filename outfile zip "&outfile" gzip;
data spreads; set spreads; format DATE yymmddn8.; run;
proc export data=spreads outfile=outfile dbms=csv replace; run;
