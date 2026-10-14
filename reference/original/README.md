# README

This folder contains the code to replicate all results in the paper and the [cascad](https://www.cascad.tech/certification/145-efficient-estimation-of-bid-ask-spreads-from-open-high-low-and-close-prices/) reproducibility certificate. Additional code and data are available at https://github.com/eguidotti/bidask

## Data Availability

The paper is based on the following data sources:

1. CRSP U.S. Stock Database (flat files for R)
2. NYSE Monthly and Daily TAQ (via WRDS)
3. Binance Historical Market Data (free access)

The data cannot be redistributed.

## Dataset List

The folder `input/` includes pseudo datasets. The pseudo datasets have the same structure as the original datasets used for the paper but they have a reduced number of entries and are filled with random values.

| File          | Location | Provided | Note        |
| ------------- | -------- | -------- | ----------- |
| `stocks.csv`  | `input/` | TRUE     | Pseudo data |
| `cryptos.csv` | `input/` | TRUE     | Pseudo data |

To overwrite the pseudo data with the actual data, follow the instructions:

1. in the folder `data/source/crsp/202112/` to generate the files `frachl.csv.gz` and `spread.csv.gz`
2. in the folder `data/source/crsptaq/202112/` to generate the file `ctm_mth.csv.gz`
3. in the folder `data/source/binance/202302/` to generate the file `bmd_mth.csv.gz`

Then, run the script `stocks.R` to generate the actual data file `input/stocks.csv`:

```
Rscript stocks.R
```

and the script `cryptos.R` to generate the actual data file `input/cryptos.csv`.

```
Rscript cryptos.R
```

## Computational Requirements

All results were generated using R 4.2.3 on a MacBook Air (M1, 2020). 

## Instructions to Replicators

Install all dependencies with [renv](https://rstudio.github.io/renv/index.html):

```R
renv::restore()
```

Run the main script to generate all results in the paper:

```R
Rscript main.R
```

The expected runtime is 10-20 minutes. The script generates an `output/` folder with all figures and tables.

## List of Tables and Programs

| Figure/Table           | Program  | Line number | Output file        | Dataset used  |
| ---------------------- | -------- | ----------- | ------------------ | ------------- |
| Figure 1               | `main.R` | 194         | `fig_1.pdf`        | `stocks.csv`  |
| Figure 2               | `main.R` | 162         | `fig_2.pdf`        |               |
| Figure 3               | `main.R` | 176         | `fig_3.pdf`        |               |
| Figure 4               | `main.R` | 228         | `fig_4.pdf`        | `stocks.csv`  |
| Figure 5               | `main.R` | 236         | `fig_5.pdf`        | `stocks.csv`  |
| Figure 6               | `main.R` | 307         | `fig_6.pdf`        | `stocks.csv`  |
| Figure 7               | `main.R` | 314         | `fig_7.pdf`        | `stocks.csv`  |
| Figure 8               | `main.R` | 321         | `fig_8.pdf`        | `cryptos.csv` |
| Table 2 / Panel A      | `main.R` | 134         | `tab_2A.tex`       |               |
| Table 2 / Panel B      | `main.R` | 148         | `tab_2B.tex`       |               |
| Table 3                | `main.R` | 200         | `tab_3.tex`        | `stocks.csv`  |
| Table 4 / Panels A-E   | `main.R` | 244         | `tab_4(A-E).tex`   | `stocks.csv`  |
| Section 6.2 - Text     | `main.R` | 207         | `sec_6.2.tex`      | `stocks.csv`  |
| **Internet Appendix**  |          |             |                    |               |
| Figure I.2             | `main.R` | 221         | `fig_I.2.pdf`      | `stocks.csv`  |
| Figure I.3             | `main.R` | 328         | `fig_I.3.pdf`      | `stocks.csv`  |
| Table I.2              | `main.R` | 214         | `tab_I.2.tex`      | `stocks.csv`  |
| Table I.4 / Panels A-E | `main.R` | 253         | `tab_I.4(A-E).tex` | `stocks.csv`  |
| Table I.5 / Panels A-E | `main.R` | 262         | `tab_I.5(A-E).tex` | `stocks.csv`  |
| Table I.6 / Panels A-E | `main.R` | 271         | `tab_I.6(A-E).tex` | `stocks.csv`  |
| Table I.7 / Panels A-E | `main.R` | 280         | `tab_I.7(A-E).tex` | `stocks.csv`  |
| Table I.8 / Panels A-E | `main.R` | 298         | `tab_I.8(A-E).tex` | `stocks.csv`  |
| Table I.9 / Panels A-E | `main.R` | 289         | `tab_I.9(A-E).tex` | `stocks.csv`  |
