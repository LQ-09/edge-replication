# TAQ data with WRDS Cloud - v2021.12

This folder contains code to process and download TAQ data up to December 2021 using WRDS Cloud.

## Prerequisites

A valid WRDS account with subscription to Monthly and Daily TAQ.

## Usage

Generate the data files below by submitting the corresponding jobs to WRDS Cloud. Download those files and place them in this folder. 

Here are some useful commands to get started with WRDS Cloud. Replace `<username>` with your WRDS username in the commands below. Windows users can refer to [this guide](https://host.kelley.iu.edu/cholden/instructions.pdf) (appendix 1 and 2) to connect to WRDS Cloud with PuTTY and to upload and download files with WinSCP.

Upload the `sas` and `sh` files from this folder to WRDS Cloud:

```bash
scp *.{sas,sh} <username>@wrds-cloud.wharton.upenn.edu:~
```

Connect to WRDS Cloud via `ssh`:

```bash
ssh <username>@wrds-cloud.wharton.upenn.edu
```

Submit jobs (see below):

```
qsub ...
```

Type the following command to check that the job is running succesfully:

```bash
qstat
```

The log file is named `<name>.o<id>` where `<name>` is job name and `id` is the job ID. You can monitor the progress of a job with:

```bash
cat <name>.o<id>
```

Type `exit` to close the connection to WRDS Cloud:

```bash
exit
```

Download the output files from WRDS Cloud

```bash
scp <username>@wrds-cloud.wharton.upenn.edu:<filename> .
```

### File `master.csv.gz`

This job takes about 1 hour to complete.

```bash
qsub -N master -cwd run.sh master
```

Contains data derived from TAQ master files and WRDS intraday indicators. CUSIP codes are obtained from Monthly TAQ between 1993-2009, and from Daily TAQ afterwards. All other data are derived from Monthly TAQ between 1993-2003, and from Daily TAQ afterwards. 

| Field    | Type      | Description                                                  |
| -------- | --------- | ------------------------------------------------------------ |
| `SYMBOL` | CHARACTER | The TAQ trading symbol                                       |
| `DATE`   | INTEGER   | Date in the format `YYYYMMDD`                                |
| `CUSIP`  | CHARACTER | CUSIP code (9 digits)                                        |
| `HJ`     | NUMERIC   | Simple averaged percent effective spread as described in [Holden and Jacobsen (2014)](https://doi.org/10.1111/jofi.12127) |
| `NUMTRD` | INTEGER   | Total number of trades during market hours                   |

### File `taqs.csv.gz`

This job takes about 1 day to complete.

```bash
qsub -N taqs -cwd run.sh taqs minute
```

Contains signed bid-ask spread estimates obtained with various methods from the Monthly TAQ database.

| Field    | Type      | Description                                                  |
| -------- | --------- | ------------------------------------------------------------ |
| `SYMBOL` | CHARACTER | The TAQ trading symbol                                       |
| `DATE`   | INTEGER   | Date in the format `YYYYMMDD`                                |
| `EDGE`   | NUMERIC   | Effective spread obtained with the efficient estimator described in this paper |
| `AR`     | NUMERIC   | Effective spread obtained with the estimator described in [Abdi & Ranaldo (2017)](https://doi.org/10.1093/rfs/hhx084) |
| `CS`     | NUMERIC   | Effective spread obtained with the estimator described in [Corwin & Shultz (2012)](https://doi.org/10.1111/j.1540-6261.2012.01729.x) |
| `ROLL`   | NUMERIC   | Effective spread obtained with the estimator described in [Roll (1984)](https://doi.org/10.1111/j.1540-6261.1984.tb03897.x) |

### File `taqms.csv.gz`

This job takes about 1 day to complete.

```bash
qsub -N taqms -cwd run.sh taqms minute
```

Contains signed bid-ask spread estimates obtained with various methods from the Daily TAQ database.

| Field    | Type      | Description                                                  |
| -------- | --------- | ------------------------------------------------------------ |
| `SYMBOL` | CHARACTER | The TAQ trading symbol                                       |
| `DATE`   | INTEGER   | Date in the format `YYYYMMDD`                                |
| `EDGE`   | NUMERIC   | Effective spread obtained with the efficient estimator described in this paper |
| `AR`     | NUMERIC   | Effective spread obtained with the estimator described in [Abdi & Ranaldo (2017)](https://doi.org/10.1093/rfs/hhx084) |
| `CS`     | NUMERIC   | Effective spread obtained with the estimator described in [Corwin & Shultz (2012)](https://doi.org/10.1111/j.1540-6261.2012.01729.x) |
| `ROLL`   | NUMERIC   | Effective spread obtained with the estimator described in [Roll (1984)](https://doi.org/10.1111/j.1540-6261.1984.tb03897.x) |

### File `nbbo.csv.gz`

This job takes about 1 month to complete.

```bash
qsub -N nbbo -cwd run.sh nbbo
```

Contains bid-ask spread estimates obtained with various methods by matching trades with NBBO quotes from the Daily TAQ database.

| Field    | Type      | Description                                                  |
| -------- | --------- | ------------------------------------------------------------ |
| `SYMBOL` | CHARACTER | The TAQ trading symbol                                       |
| `DATE`   | INTEGER   | Date in the format `YYYYMMDD`                                |
| `QM`     | NUMERIC   | Effective spread computed using the quoted midpoint as in [Holden and Jacobsen (2014)](https://doi.org/10.1111/jofi.12127) |
| `QW`     | NUMERIC   | Effective spread computed using the quoted weighted-midpoint as in [Hagstromer (2021)](https://doi.org/10.1016/j.jfineco.2021.04.018) |

