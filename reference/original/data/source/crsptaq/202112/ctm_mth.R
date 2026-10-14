library(RSQLite)
library(eguidotti)


# Data tables
tables <- list(
  
  "../../crsp/202112" = c(
    "sfz_nam.rds"
  ),
  
  "../../taq/202112" = c(
    "master.csv.gz",
    "taqms.csv.gz",
    "taqs.csv.gz",
    "nbbo.csv.gz"
  )
  
)

# Open connection to database
db <- tempfile()
conn <- dbConnect(SQLite(), db)

# Import CRSP data
dbImport(
  conn, 
  table = names(tables[1]), 
  pattern = paste0(tables[[1]], collapse = "|"),
  index = c("NCUSIP9", "TICKER")
)

# Import TAQ data
dbImport(
  conn, 
  table = names(tables[2]),
  pattern = paste0(tables[[2]], collapse = "|"),
  index = c("SYMBOL", "DATE", "CUSIP")
)

# Merge CRSP and TAQ
x <- dbGetQuery(conn, "
SELECT
  nam.KYPERMNO AS KYPERMNO,
  mast.DATE / 100 AS YYYYMM,
  mast.NUMTRD AS NUMTRD,
  mast.HJ AS HJ,
  q.QM AS QM,
  q.QW AS QW,
  ms.EDGE AS EDGEMS,
  ms.AR AS ARMS,
  ms.CS AS CSMS,
  ms.ROLL AS ROLLMS,
  s.EDGE AS EDGES,
  s.AR AS ARS,
  s.CS AS CSS,
  s.ROLL AS ROLLS

FROM
  sfz_nam AS nam

  JOIN master AS mast ON
    mast.CUSIP = nam.NCUSIP9 AND 
    mast.SYMBOL = nam.TICKER AND 
    mast.DATE BETWEEN nam.NAMEDT AND nam.NAMEENDDT

  LEFT JOIN taqms AS ms ON
    mast.SYMBOL = ms.SYMBOL AND
    mast.DATE = ms.DATE
    
  LEFT JOIN taqs AS s ON
    mast.SYMBOL = s.SYMBOL AND
    mast.DATE = s.DATE

  LEFT JOIN nbbo AS q ON
    mast.SYMBOL = q.SYMBOL AND
    mast.DATE = q.DATE
")

# Convert to data table
setDT(x, key = c("KYPERMNO", "YYYYMM"))

# Winsorize benchmarks
bks <- c("HJ", "QM", "QW")
fun <- function(x) winsorize(ifelse(x > 0, x, NA), pmin = 0, pmax = 0.995)
x[, (bks) := lapply(.SD, fun), .SDcols = bks, by = YYYYMM]

# Compute (signed) square spread
sp <- c(bks, "EDGEMS", "ARMS", "CSMS", "ROLLMS", "EDGES", "ARS", "CSS", "ROLLS")
x[, (sp) := lapply(.SD, function(s) s*abs(s)), .SDcols = sp]

# Compute (signed) mean square spread and other averages by stock-month
x <- x[, lapply(.SD, mean), by = .(KYPERMNO, YYYYMM)]

# Compute (signed) root mean square spread
x[, (sp) := lapply(.SD, function(s) sign(s)*sqrt(abs(s))), .SDcols = sp]

# Export
swrite(x, file = "ctm_mth.csv.gz", key = c("KYPERMNO", "YYYYMM"))

# Close connection to database
dbDisconnect(conn)
unlink(db)
