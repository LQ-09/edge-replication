# CRSP/TAQ merged database - v2021.12

This folder contains code to merge data obtained from TAQ with the CRSP database released in December 2021.

## Prerequisites

Satisfy the prerequisites in the folder `crsp/202112`. Generate the files `master.csv.gz`, `nbbo.csv.gz`, `taqms.csv.gz`, `taqs.csv.gz` in the folder `taq/202112`.

## Installation

Install the dependencies with [renv](https://rstudio.github.io/renv/index.html):

```R
renv::restore()
```

## Usage

Generate the following data files by running the corresponding R script.

### File `ctm_mth.csv.gz`

```R
Rscript ctm_mth.R
```

Contains monthly CRSP/TAQ merged data. Bid-ask spread estimates are signed and they are the root mean square spread within the month. A value of 0.01 corresponds to a spread of 1%.

| Field             | Type    | Description                                                  | Data                   |
| ----------------- | ------- | ------------------------------------------------------------ | ---------------------- |
| `KYPERMNO`        | INTEGER | Unique permanent security identification number assigned by CRSP to each security | CRSP                   |
| `YYYYMM`          | INTEGER | Year-month in the format `YYYYMM`                            | CRSP                   |
| `NUMTRD`          | INTEGER | Average number of trades during market hours                 | WRDS IID               |
| `HJ`              | NUMERIC | Effective spread pre-computed by WRDS as described in [Holden and Jacobsen (2014)](https://doi.org/10.1111/jofi.12127) | WRDS IID               |
| `QM`              | NUMERIC | Effective spread computed using the quoted midpoint as in [Holden and Jacobsen (2014)](https://doi.org/10.1111/jofi.12127). This is a replication of `HJ`. | Daily TAQ              |
| `QW`              | NUMERIC | Effective spread computed using the quoted weighted-midpoint as in [Hagstromer (2021)](https://doi.org/10.1016/j.jfineco.2021.04.018) | Daily TAQ              |
| `EDGEMS`, `EDGES` | NUMERIC | Effective spread obtained with the efficient estimator described in this paper | Daily TAQ, Monthly TAQ |
| `ARMS`, `ARS`     | NUMERIC | Effective spread obtained with the estimator described in [Abdi & Ranaldo (2017)](https://doi.org/10.1093/rfs/hhx084) | Daily TAQ, Monthly TAQ |
| `CSMS`, `CSS`     | NUMERIC | Effective spread obtained with the estimator described in [Corwin & Shultz (2012)](https://doi.org/10.1111/j.1540-6261.2012.01729.x) | Daily TAQ, Monthly TAQ |
| `ROLLMS`, `ROLLS` | NUMERIC | Effective spread obtained with the estimator described in [Roll (1984)](https://doi.org/10.1111/j.1540-6261.1984.tb03897.x) | Daily TAQ, Monthly TAQ |
