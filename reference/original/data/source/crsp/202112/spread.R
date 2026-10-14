library(bidask)
library(RSQLite)
library(progress)
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
  dp.CALDT AS YYYYMMDD,
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
setDT(ohlc, key = c("KYPERMNO", "YYYYMMDD"))

# Convert days to dates to speed up xts conversion
ohlc$YYYYMMDD <- as.Date(as.character(ohlc$YYYYMMDD), format = "%Y%m%d")

# Compute and store the monthly spread estimates for each stock
keys <- unique(ohlc$KYPERMNO)
pb <- progress_bar$new(total = length(keys))
for(k in keys){
  
  # print progress
  pb$tick()
  
  # get stock data
  x <- ohlc[KYPERMNO == k]
  x <- xts::xts(x[,c("OPEN", "HIGH", "LOW", "CLOSE")], order.by = x$YYYYMMDD)
  if(nrow(x) < 3) next
  
  # endpoints
  endpoints <- xts::endpoints(x, on = "months")
  
  # compute estimates
  method <- c("EDGE", "OHL", "CHL", "OHLC", "CHLO", "AR", "CS", "ROLL")
  es <- spread(x, width = endpoints, method = method, sign = TRUE)
  
  # write estimates
  dbWriteTable(
    conn, 
    name = "es", 
    append = TRUE,
    value = cbind(
      "KYPERMNO" = k, 
      "YYYYMM" = as.integer(format(zoo::index(es), "%Y%m")),
      data.frame(es)
    )
  )

}

# Read quoted spreads
qs <- dbGetQuery(conn, "
SELECT
  KYPERMNO AS KYPERMNO,
  CALDT / 100 AS YYYYMM,
  AVG(2 * (ASK - BID) / (ASK + BID)) AS QS
  
FROM
  sfz_ds_dly

WHERE
  ASK > BID
  
GROUP BY
  KYPERMNO, 
  CALDT / 100
")

# Read effective spreads
es <- dbReadTable(conn, name = "es")

# Merge spreads
x <- merge(es, qs, by = c("KYPERMNO", "YYYYMM"), all = TRUE)

# Export
swrite(x, file = "spread.csv.gz", key = c("KYPERMNO", "YYYYMM"))

# Close database connection
dbDisconnect(conn)
unlink(db)
