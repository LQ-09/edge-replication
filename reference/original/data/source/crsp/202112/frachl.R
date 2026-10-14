library(RSQLite)
library(eguidotti)


# Data tables
tables <- list(
  
  "." = c(
    "sfz_dp_dly.rds",
    "sfz_ds_dly.rds"
  )
  
)

# Open connection to database
db <- tempfile()
conn <- dbConnect(SQLite(), db)

# Import data
dbImport(
  conn, 
  table = names(tables[1]), 
  pattern = paste0(tables[[1]], collapse = "|"),
  index = c("KYPERMNO", "CALDT", "YYYYMMDD")
)

# Get OHLC daily prices
ohlc <- dbGetQuery(conn, "
SELECT
  dp.KYPERMNO AS KYPERMNO,
  dp.CALDT / 100 AS YYYYMM,
  CASE 
    WHEN ds.OPENPRC BETWEEN ds.BIDLO AND ds.ASKHI 
    THEN ds.OPENPRC
  END AS OPEN,
  ds.ASKHI AS HIGH,
  ds.BIDLO AS LOW,
  dp.PRC AS CLOSE

FROM
  sfz_dp_dly AS dp

  JOIN sfz_ds_dly AS ds ON
    dp.KYPERMNO = ds.KYPERMNO AND
    dp.CALDT = ds.CALDT
    
WHERE
  ds.BIDLO > 0 AND 
  ds.ASKHI > 0 AND 
  dp.PRC BETWEEN ds.BIDLO AND ds.ASKHI
")

# Convert to data table
setDT(ohlc, key = c("KYPERMNO", "YYYYMM"))

# Compute fraction of times where the open or close matches the high or low
x <- ohlc[, .(
  FRACOH = mean(OPEN==HIGH),
  FRACOL = mean(OPEN==LOW),
  FRACCH = mean(CLOSE==HIGH),
  FRACCL = mean(CLOSE==LOW)
), by = .(KYPERMNO, YYYYMM)]

# Export
swrite(x, file = "frachl.csv.gz", key = c("KYPERMNO", "YYYYMM"))

# Close database connection
dbDisconnect(conn)
unlink(db)
