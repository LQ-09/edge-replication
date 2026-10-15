# Reproduce the empirical pilot

Requires Python 3.12, the repository dependencies, and authorized WRDS extracts. No password, API key or data license is bundled. A Safari login alone is not a PostgreSQL credential. The recorded extraction used the WRDS web forms and its logged-in Jupyter/SAS environment.

## 1. Install local Python dependencies

From the repository root:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-lock.txt
python -m unittest discover -s tests -v
```

`requirements.txt` lists direct dependencies; `requirements-lock.txt` freezes the complete tested Python environment. R dependencies are separate and restored with `renv`, as described in README. Python does not need the author's 75-package R environment.

## 2. Download the six-month daily sample

WRDS CRSP → Annual Update → Stock Version 2 → Daily Stock File. Select tickers AAPL MSFT JPM XOM NVDA, dates 2024-01-01–2024-06-30, CSV, ISO dates. The recorded query selected all 96 fields. Save as `data/raw/crsp_2024_h1.csv`.

Required CRSP columns: PERMNO, DlyCalDt, TradingSymbol, SecurityType, SecuritySubType, ShareType, USIncFlg, IssuerType, TradingStatusFlg, DlyCumFacPr, DlyOpen, DlyHigh, DlyLow, DlyClose, DlyVol. Retain CUSIP9 and company name for event identity review.

WRDS TAQ → Millisecond Intraday Indicators. Same five roots and dates. Save as `data/raw/iid_2024_h1.csv`. Required columns: DATE, SYM_ROOT, SYM_SUFFIX, EffectiveSpread_Percent_Ave. The recorded query selected all 198 fields. Do not remove suffixes manually: the adapter logs those exclusions.

```sh
python -m src.prepare_wrds --crsp data/raw/crsp_2024_h1.csv --iid data/raw/iid_2024_h1.csv
python -m src.pipeline daily --config config/reproduction.yaml
```

The frozen `config/reproduction.yaml` documents the verified 2026-10-15 extract and chosen sample. For another schema/sample, copy `config/project_config.yaml` to an ignored `config/local.yaml`, verify its metadata and update mappings. Never blindly mark a new source verified.

## 3. Export the intraday windows inside WRDS

Review `sample_manifest.csv` and `config/earnings_events.csv` before reusing the sample. In WRDS Jupyter, place those two files and `src/export_wrds_cloud.py` in the same project structure. Run the script in the WRDS Python kernel. It uses the WRDS-provided `saspy`, raw TAQ `ctm_YYYYMMDD` and `complete_nbbo_YYYYMMDD`, retaining original fields and TIME20.9 precision. It downloads only 15 stock-days and the three specified windows, with five seconds of quote lookback.

```python
from src.export_wrds_cloud import export
archive = export()
print(archive)
```

Download `edge_project_exports/edge_event_windows.zip` through the Jupyter file browser (Download), then extract its CSVs to `data/raw/event_windows/`. The script fails if its export folder already exists, rather than replacing cached evidence. Its SAS log is preserved in the export folder.

The initial pilot was a separate full-session MSFT 2024-01-31 query; this is retained locally as supporting evidence. It is not required to download that day twice for a repeat extension run.

Optional earnings cross-check used this SAS query, with the institution's Compustat subscription:

```sas
proc sql;
create table work.edge_rdq as
select gvkey,tic,cusip,datadate,rdq from comp.fundq
where tic in ('AAPL','MSFT','JPM','XOM','NVDA')
  and rdq between '01NOV2023'd and '30JUN2024'd
  and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C';
quit;
```

The baseline events use the public IR sources in the committed event CSV, not an inaccessible CCM link. RDQ supplies dates, not announcement times. The XOM Compustat-vs-CRSP CUSIP difference is explicitly documented in methodology.

## 4. Normalize and run

```sh
python -m src.prepare_taq --directory data/raw/event_windows
python -m src.pipeline intraday --config config/reproduction.yaml --output private_outputs/intraday_verified
```

Expected baseline: 30 monthly pairs; 45 candidate intervals, 44 accepted. If the underlying WRDS vintage changes, counts or values may change; inspect the audit instead of forcing the old totals. Each run saves source SHA-256 hashes and exact settings. Repeated runs require a new `--output private_outputs/<name>`; prepared input folders are also protected from replacement.

Local outputs: `private_outputs/daily/` and `private_outputs/intraday_verified/`. These include clean Parquet data, final CSV comparisons, plots, descriptive statistics, interval counts, exclusions and run manifests. These directories and `data/` are ignored by Git. Do not force-add them.

## Validation evidence

`tests/` contains synthetic fixtures only. `docs/estimator_parity.json` and `tests/fixtures/parity/` document signed R/Python agreement. `docs/analysis_validation.json` describes independent checks on the observed run. The final report distinguishes these checks from unperformed robustness studies.

For the exact documented baseline, run `python scripts/verify_observed_run.py` after both pipelines. It independently checks the saved benchmarks and 100 deterministic raw-quote matches; it is not a general validator for a changed sample.
