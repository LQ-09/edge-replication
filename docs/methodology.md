# Methods and deviations from the full paper

## Research design

This is the bounded capstone specified in the project PDF: author Table 2 simulation, a five-stock/six-month daily empirical pilot, and a small earnings-adjacent intraday extension. It does not reproduce every empirical table in the JFE paper. Data were retrieved from WRDS on 2026-10-15. No directional finding was required or used to select the sample.

## Simulation

`run_simulation.R` retains the author's original DGP, seed order, 21-day endpoints and signed-then-truncate-zero transformation. Ten scenarios each contain 10,000 windows. All 240 mean/SD/zero-fraction cells match the supplied author TeX tables at printed precision. Independently, all 160 mean/SD cells match the published paper's Table 2, PDF page 8. The paper does not print the zero-fraction cells. See `results/published_table2_comparison.csv` and `docs/published_table_verification.json`.

## Daily panel

AAPL, MSFT, JPM, XOM and NVDA, 2024-01-01 through 2024-06-30. CRSP annual-update CIZ daily stock file provides point-in-time PERMNO, TradingSymbol, security classifications, OHLC, raw volume and cumulative price factors. Keep active US corporate common ordinary shares: EQTY/COM/NS, USIncFlg=Y, IssuerType=CORP, TradingStatusFlg=A. Nonpositive prices, impossible OHLC, missing volume, duplicate stock-days and non-exchange sessions are excluded or rejected and logged.

Divide all four price fields by DlyCumFacPr. The WRDS CIZ documentation maps this factor to legacy CFACPR. NVDA's June 2024 10-for-1 split provides an explicit continuity check: factor 10 before June 10, factor 1 thereafter. Volume remains actual reported shares; dollar turnover uses unadjusted closing price times actual shares, not split-adjusted price times raw shares. Adjusted OHLC is used only for the estimator and normalized range.

Apply the unchanged authors' Python EDGE at pinned commit `2dbafe0087e609c7b153e1a43b7ce6c923daf89c`, with `sign=True`, then truncate negative signed estimates at zero. Each calendar month is evaluated independently. Require all expected exchange sessions (and at least 15 bars); do not compress missing sessions into consecutive observations. This calendar-window boundary differs from the original continuous simulated-window endpoint convention, deliberately following the capstone baseline.

## Daily high-frequency benchmark

WRDS millisecond IID field `EffectiveSpread_Percent_Ave` is the simple trade-average relative effective spread, Formula 4 of the WRDS DTAQ IID Manual 2.0 (pp. 12, 24–25): mean of 2D(P−M)/M. Despite its name, it is stored as a decimal ratio, not percentage points. Keep blank SYM_SUFFIX only; join SYM_ROOT to CRSP TradingSymbol on the exact date, rejecting ambiguous mappings. The initial extract includes JPM preferred-share suffixes; these are excluded explicitly.

Keep positive finite daily spreads. Within each calendar month, cap the daily observations at their one-sided 99.5th percentile (linear interpolation), then take the root mean square by PERMNO/month. The winsorization population is the available five-stock sample, **not the full paper's US equity cross-section**. Record caps and raw/adjusted fields. Require at least 15 days and at least 80% overlap; actual matching diagnostics report exact counts. Compare decimal EDGE and benchmark values; convert errors to basis points by multiplying by 10,000. RMSE is on linear spreads, **not** the paper's log-spread RMSE. Small-sample Pearson correlation is descriptive.

## Earnings identity and labels

One first-quarter-2024 announcement per company is verified against the company's public investor-relations release and corroborated with Compustat `fundq.rdq`. The downloaded calendar covers November 2023–June 2024 and confirms no other quarterly announcement in the selected control buffers. CCM access was denied; no CCM link is claimed. Four companies also match Compustat CUSIP exactly to the CRSP event-date CUSIP9. XOM's downloaded Compustat CUSIP differs from CRSP; its event is therefore sourced from the official ExxonMobil announcement, with CRSP daily ticker/name and the historical SEC CUSIP identifying the security. The mismatch is retained in the private cross-check table.

All analysis labels are **earnings-adjacent** or **control**. Release timing is `unknown` in the committed event list; a conference-call time is not treated as the release timestamp. Thus there is no strict pre/post or causal announcement-effect claim. Controls are nearby exchange sessions, more than two sessions from any verified quarterly announcement and no more than ten sessions from the selected announcement. Public sources and selections are in `config/earnings_events.csv` and `sample_manifest.csv`.

## TAQ matching and intervals

A full-day MSFT 2024-01-31 pilot preceded expansion. The extension caches only three half-hour windows per stock-day (open 09:30–10:00, midday 12:00–12:30, close 15:30–16:00 ET), with five seconds of quote lookback before each window. Fifteen stock-days are selected, three per company. This is a deliberately small extract, not a full-universe/year TAQ pull.

Source trades are raw `ctm_YYYYMMDD`; source quotes are WRDS `complete_nbbo_YYYYMMDD`, which augments the official NBBO with qualifying consolidated quotes. Use BEST_BID/BEST_ASK and positive displayed sizes, not a single exchange's BBO. Preserve source time precision with SAS TIME20.9 export and Python nanosecond timestamps; localize explicitly to America/New_York. No minute rounding is used for quote matching.

Keep positive price/size, uncorrected trade code 00, regular trades with optional F (intermarket sweep) and I (odd lot); normalize whitespace only. Exclude other sale conditions, including status messages Q/M, out-of-sequence/special settlement trades and corrections. Quote baseline accepts condition R with positive bid/ask/sizes and ask>bid. Invalid, locked or crossed quote updates remain in the time series as barriers: they invalidate the preceding good quote instead of allowing it to persist. The complete NBBO lacks an exchange sequence field. `source_row` is only a stable exported row ID; repeated quote timestamps are treated as invalid barriers, never ordered by an invented exchange sequence.

Match each trade to the strictly preceding quote within the same stock-day, at most five seconds old. Exclude exact-time matches. Calculate effective spread = 2|P−(bid+ask)/2|/((bid+ask)/2). This is an absolute-distance baseline, while the daily IID field uses signed trade classification. It is documented as a related benchmark, not a claim that we recreate IID exactly.

Create one-minute OHLC from retained trades, ordered by source timestamp and trade sequence. Require at least two trades per valid minute, at least 20 valid contiguous minutes per interval, at least 90% of interval trades in valid bars, and at least 90% quote matching among those trades. Both EDGE and the RMS trade-level effective spread use the valid-bar horizon; unmatched trades cannot contribute a benchmark. Record arithmetic mean separately, never substitute it for RMS. Exclude half-days; gaps in the measured windows fail the continuity/coverage gate. We did not obtain a separate official halt registry: “session reviewed” means the exchange calendar and measured-window coverage were checked, not a certification of no halt elsewhere in the day.

## Interpretation limits

Twenty to thirty bars are noisy for a daily-OHLC estimator applied to intraday windows. Zero estimates follow the prescribed truncation, not observed zero transaction cost. Five stocks, six months, one event per company and one control per event do not support population inference or causal effects. Volatility, volume, spread levels and common market news may confound comparisons. No event is removed because its result is inconvenient.

The baseline uses SIP timestamps as supplied by WRDS Complete NBBO. WRDS has flagged possible post-2015 look-ahead issues from SIP-versus-participant timestamp differences and is revising its matching methodology. Strictly preceding SIP timestamps prevent future-SIP matches but do not resolve that economic-timing issue. Source precision also reflects SAS numeric storage. A participant-timestamp sensitivity study is outside this bounded implementation and should precede strong microstructure claims.

## Source references

- [Ardia, Guidotti and Kroencke (2024), published paper](https://jfe-journal.org/wp-content/uploads/Efficient-estimation-of-bid-ask-spreads-from-open.pdf).
- [Author EDGE project](https://bidask.eguidotti.com/).
- [WRDS CIZ cumulative adjustment factors](https://wrds-www.wharton.upenn.edu/pages/support/support-articles/crsp/stock-v2-siz/cumulative-adustment-factors-in-stock-v2/).
- [WRDS IID Manual 2.0, login required](https://wrds-www.wharton.upenn.edu/documents/1038/WRDS_DTAQ_IID_Manual_2.0_vzJomVO.pdf).
- [NYSE Daily TAQ Client Specification v4.0](https://www.nyse.com/publicdocs/nyse/data/Daily_TAQ_Client_Spec_v4.0.pdf), applicable to the selected January–February 2024 sample.
- [SEC historical XOM common-stock identity](https://www.sec.gov/Archives/edgar/data/34088/000009375124000836/Exxon_Mobil_Corp.htm).
