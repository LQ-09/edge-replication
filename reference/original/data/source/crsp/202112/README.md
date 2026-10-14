# CRSP U.S. stock database - v2021.12

This folder is designed to store the [CRSP U.S. Stock flat files for R](https://www.crsp.org/products/research-products/crsp-us-stock-databases) released by CRSP in December 2021. It also provides code to generate derived data.

## Prerequisites

Download the CRSP U.S. Stock flat files for R (`sfz_*.rds` files) released by CRSP in December 2021 and place them into this folder.

## Installation

Install the dependencies with [renv](https://rstudio.github.io/renv/index.html):

```R
renv::restore()
```

## Usage

Generate the following data files by running the corresponding R script.

### File `frachl.csv.gz`

```R
Rscript frachl.R
```

Contains the fractions of days where the open or close prices match the high or low prices.

| Field      | Type    | Description                                                  |
| ---------- | ------- | ------------------------------------------------------------ |
| `KYPERMNO` | INTEGER | Unique permanent security identification number assigned by CRSP to each security |
| `YYYYMM`   | INTEGER | Year-month in the format `YYYYMM`                            |
| `FRACOH`   | NUMERIC | Fraction of days where the opening price is the highest price |
| `FRACOL`   | NUMERIC | Fraction of days where the opening price is the lowest price |
| `FRACCH`   | NUMERIC | Fraction of days where the closing price is the highest price |
| `FRACCL`   | NUMERIC | Fraction of days where the closing price is the lowest price |

### File `spread.csv.gz`

```R
Rscript spread.R
```

Contains signed bid-ask spread estimates obtained with various methods. A value of 0.01 corresponds to a spread of 1%.

| Field                        | Type    | Description                                                  |
| ---------------------------- | ------- | ------------------------------------------------------------ |
| `KYPERMNO`                   | INTEGER | Unique permanent security identification number assigned by CRSP to each security |
| `YYYYMM`                     | INTEGER | Year-month in the format `YYYYMM`                            |
| `EDGE`                       | NUMERIC | Effective spread obtained with the efficient estimator described in this paper |
| `OHL`, `CHL`, `OHLC`, `CHLO` | NUMERIC | Effective spread obtained with the estimators described in this paper |
| `AR`                         | NUMERIC | Effective spread obtained with the estimator described in [Abdi & Ranaldo (2017)](https://doi.org/10.1093/rfs/hhx084) |
| `CS`                         | NUMERIC | Effective spread obtained with the estimator described in [Corwin & Shultz (2012)](https://doi.org/10.1111/j.1540-6261.2012.01729.x) |
| `ROLL`                       | NUMERIC | Effective spread obtained with the estimator described in [Roll (1984)](https://doi.org/10.1111/j.1540-6261.1984.tb03897.x) |
| `QS`                         | NUMERIC | Average end-of-day quoted spread within the month            |

