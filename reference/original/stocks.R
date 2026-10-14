library(here)
library(RSQLite)
library(eguidotti)


# Data tables
tables <- list(
  
  "{data}/source/crsp/202112" = c(
    "sfz_nam.rds",
    "sfz_agg_mth.rds",
    "spread.csv.gz",
    "frachl.csv.gz"
  ),
  
  "{data}/source/crsptaq/202112" = c(
    "ctm_mth.csv.gz"
  )
  
)

# Set path to data
data <- Sys.getenv("DATA")
names(tables) <- gsub("{data}", data, names(tables), fixed = TRUE)

# Open connection to database
db <- tempfile()
conn <- dbConnect(SQLite(), db)

# Import CRSP data
dbImport(
  conn, 
  table = names(tables[1]),
  pattern = paste0(tables[[1]], collapse = "|"),
  index = c("KYPERMNO", "YYYYMM")
)

# Import CRSP/TAQ data
dbImport(
  conn, 
  table = names(tables[2]),
  pattern = paste0(tables[[2]], collapse = "|"),
  index = c("KYPERMNO", "YYYYMM")
)

# Merge data
x <- dbGetQuery(conn, "
SELECT
  m.KYPERMNO AS KYPERMNO,
  m.YYYYMM AS YYYYMM,
  n.EXCHCD AS EXCHCD,
  m.MTHCAP * 1000 AS ME,
  f.FRACOH AS FRACOH,
  f.FRACOL AS FRACOL,
  f.FRACCH AS FRACCH,
  f.FRACCL AS FRACCL,
  t.NUMTRD AS NUMTRD,
  t.HJ AS HJ,
  t.QM AS QM,
  t.QW AS QW,
  CASE WHEN t.YYYYMM >= 200310 THEN t.EDGEMS END AS EDGEMS,
  t.EDGES AS EDGES,
  s.EDGE AS EDGE,
  COALESCE(s.EDGE, s.CHL) AS EDGECHL,
  s.OHL AS OHL,
  s.CHL AS CHL,
  s.OHLC AS OHLC,
  s.CHLO AS CHLO,
  s.AR AS AR,
  s.CS AS CS,
  s.ROLL AS ROLL,
  s.QS AS QS
  
FROM
  sfz_agg_mth AS m

  JOIN spread AS s ON
    m.KYPERMNO = s.KYPERMNO AND 
    m.YYYYMM = s.YYYYMM
    
  JOIN sfz_nam AS n ON
    m.KYPERMNO = n.KYPERMNO AND 
    m.MCALDT BETWEEN n.NAMEDT AND n.NAMEENDDT
    
  JOIN frachl AS f ON
    m.KYPERMNO = f.KYPERMNO AND 
    m.YYYYMM = f.YYYYMM
    
  LEFT JOIN ctm_mth AS t ON
    m.KYPERMNO = t.KYPERMNO AND 
    m.YYYYMM = t.YYYYMM AND
    t.YYYYMM >= 199305
    
WHERE
  n.EXCHCD IN (1, 2, 3) AND
  n.SHRCD IN (10, 11)
")

# Export
file <- here("input", "stocks.csv")
file.remove(file)
swrite(x, file = file, key = c("KYPERMNO", "YYYYMM"))

# Close connection to database
dbDisconnect(conn)
unlink(db)
