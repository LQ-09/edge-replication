# Binance - v2023.02

This folder contains code to download historical cryptocurrency data from [Binance Market Data](https://www.binance.com/en/landing/data) up to February 2023.

## Installation

Install the dependencies with [renv](https://rstudio.github.io/renv/index.html):

```R
renv::restore()
```

## Usage

Generate the following data files by running the corresponding R script.

### File `bmd_mth.csv.gz`

```R
Rscript bmd_mth.R
```

Contains monthly data derived from open, high, low, and close prices at daily, hourly, and minute frequency. 

| Field    | Type      | Description                                                  |
| -------- | --------- | ------------------------------------------------------------ |
| `SYMBOL` | CHARACTER | Trading pair                                                 |
| `YYYYMM` | INTEGER   | Year-month in the format `YYYYMM`                            |
| `FREQ`   | CHARACTER | Frequency of open, high, low, and close prices (`1d`, `1h`, `1m`) |
| `NUMTRD` | INTEGER   | Total number of trades within the month                      |
| `PRC`    | NUMERIC   | Price at the end of the month                                |
| `VOL`    | NUMERIC   | Total volume traded within the month in units of base currency |
| `PRCVOL` | NUMERIC   | Total volume traded within the month in units of quote currency |
| `SDRET`  | NUMERIC   | Standard deviation of close-to-close returns                 |
| `EDGE`   | NUMERIC   | Effective bid-ask spread as described in this paper          |
| `AR`     | NUMERIC   | Effective bid-ask spread as as described in [Abdi & Ranaldo (2017)](https://doi.org/10.1093/rfs/hhx084) |
| `CS`     | NUMERIC   | Effective bid-ask spread as described in [Corwin & Shultz (2012)](https://doi.org/10.1111/j.1540-6261.2012.01729.x) |
| `ROLL`   | NUMERIC   | Effective bid-ask spread as described in [Roll (1984)](https://doi.org/10.1111/j.1540-6261.1984.tb03897.x) |
