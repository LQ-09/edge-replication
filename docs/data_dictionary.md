# Data dictionary

All spread values are decimal ratios unless a name ends in `_bps`. One basis point = 0.0001. All intraday times are America/New_York, with source fractional precision retained. Licensed inputs and row-level outputs remain under ignored `data/` and `private_outputs/`.

| Table / field | Meaning / source |
|---|---|
| CRSP `permno`, `date`, `symbol` | Permanent issue identifier, trading date, point-in-time TradingSymbol |
| CRSP `open`, `high`, `low`, `close` | DlyOpen/High/Low/Close divided by DlyCumFacPr; positive USD per adjusted share |
| CRSP `volume` | Actual DlyVol, shares; not split adjusted |
| CRSP `dollar_volume` | Unadjusted DlyClose × DlyVol, USD |
| CRSP `common_stock` | Verified eligibility flag from CIZ security headers |
| CRSP `daily_range` | (high−low)/close; unitless |
| IID `spread` | Raw EffectiveSpread_Percent_Ave, decimal; signed classification daily average |
| IID `spread`, `adjusted_spread`, `winsor_cap` | Converted raw value, month-capped value, available-sample 99.5% cap |
| Monthly `month` | Calendar month YYYY-MM |
| Monthly `edge_spread` | Signed author EDGE truncated at zero; NaN if insufficient/undefined |
| Monthly `hf_benchmark` | RMS of winsorized daily IID spreads |
| `n_ohlc_days`, `n_benchmark_days`, `n_common_days` | Daily observation counts and overlap |
| `expected_sessions`, `missing_sessions`, `missing_dates` | XNYS calendar coverage, including exact absent dates |
| `day_overlap_fraction` | Common days divided by larger of the two daily counts |
| `matched` | Both estimates finite and overlap gate passes |
| Events `event_id`, `announcement_date`, `source` | Stable event label, verified release date, public IR URL |
| Events `release_timing` | unknown in baseline; prevents an unverified strict pre/post label |
| Manifest `role` | event_adjacent or control |
| Manifest `session_reviewed`, `exclusion_reason` | Calendar and analysis-window review flag, explicit exclusion if any |
| Trades `timestamp`, `sequence` | TIME_M with explicit timezone; actual TR_SEQNUM |
| Trades `price`, `size` | PRICE in USD, SIZE in shares |
| Trades `condition`, `correction` | TR_SCOND without spaces; TR_CORR kept as string, e.g. 00 |
| Quotes `bid`, `ask`, `bid_size`, `ask_size` | BEST_BID, BEST_ASK, Best_BidSizeShares, Best_AskSizeShares |
| Quotes `sequence` | Exported source_row only; not a market sequence number |
| Quotes `condition` | QU_COND; ambiguous timestamp ties marked invalid |
| Matched `quote_timestamp`, `quote_age_seconds`, `quote_matched` | Strictly preceding source quote, age, validity/staleness gate |
| Matched `effective_spread` | 2×abs(price−midpoint)/midpoint; missing for failed matches |
| Bars `minute`, `open/high/low/close`, `n_trades`, `volume`, `valid_bar` | Retained-trade one-minute bars and coverage; at least two trades |
| Interval `window`, `event_label` | open/midday/close and earnings-adjacent/control |
| Interval `hf_benchmark` | RMS trade-level effective spread over matched trades in valid minute bars |
| Interval `arithmetic_hf_spread` | Arithmetic average; descriptive only, not RMS target |
| Interval `absolute_error_bps` | 10,000 × abs(EDGE−HF RMS) |
| Interval `n_trades`, `n_estimation_trades`, `n_matched_trades` | Clean interval trades, valid-bar trades, valid quote matches |
| Interval `n_valid_bars`, `expected_bars` | Actual accepted minutes and nominal interval length (30) |
| Interval `quote_match_fraction`, `bar_trade_fraction` | Matched/estimation trades; estimation/all clean interval trades |
| Interval `contiguous_bars`, `status` | No internal minute gaps; accepted or failed coverage/undefined estimate |
| Audit `before`, `after`, `excluded` | Counts at each sequential filter; quote-invalid rows are logged but retained as barriers |
| Manifest `sha256`, `rows`, `config` | Input fingerprint, record count and exact settings for a particular run |

`run_manifest.json` records failure states as well as successful runs. An existing output folder is never overwritten. The initial failed pre-configuration attempt remains privately recorded; the accepted extension run is `private_outputs/intraday_verified/`.
