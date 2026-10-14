library(eguidotti)
library(xts)
library(httr)
library(xml2)
library(digest)
library(bidask)
library(RSQLite)
library(progress)


# Set time range
start <- 201707
end <- 202302

# Unset timeout to allow download of large files
options(timeout = 0)

# Set time zone
Sys.setenv(TZ = "UTC")

# Read cached urls from file
keys <- c()
keyfile <- "keys.csv"
cached <- file.exists(keyfile)
if(cached) keys <- fread(keyfile)$keys

# Else query binance bucket
baseurl <- "https://s3-ap-northeast-1.amazonaws.com/data.binance.vision/"
query <- list("prefix" = "data/spot/monthly/klines/", "list-type" = "2")
token <- NULL
while(!cached){
  
  if(!is.null(token)){
    query[['continuation-token']] = token
  }
  
  resp <- GET(baseurl, query = query)
  cont <- content(resp, as = "text", encoding = "UTF-8")
  x <- xml2::as_list(xml2::read_xml(cont))$ListBucketResult
  
  for(content in x){
    key <- content$Key[[1]]
    if(!is.null(key)){
      if(!endsWith(key, "CHECKSUM")){
        info <- strsplit(gsub(".zip", "", basename(key), fixed = TRUE), "-")
        if(info[[1]][2] %in% c("1m", "1h", "1d")){
          yyyymm <- as.integer(paste0(info[[1]][3], info[[1]][4]))
          if(yyyymm >= start & yyyymm <= end){
            keys[length(keys)+1] <- key
          }
        }
      }
    }
  }
  
  print(paste("Total keys:", length(keys)))
  
  if(x$IsTruncated[[1]] == 'true')
    token <- x$NextContinuationToken[[1]]
  else
    break
  
}

# Cache urls
if(!cached) fwrite(data.frame("keys" = keys), file = keyfile)

# Open connection to database
db <- "bmd.db"
conn <- dbConnect(RSQLite::SQLite(), db)

# Process each file
pb <- progress_bar$new(total = length(keys), force = TRUE)
for(key in keys){
  
  # print progress
  pb$tick()
  
  # file info
  info <- strsplit(gsub(".zip", "", basename(key), fixed = TRUE), "-")[[1]]
  
  # skip if already done
  sql <- sprintf("
     SELECT 1 
     FROM mth
     WHERE SYMBOL='%s' AND FREQ='%s' AND YYYYMM=%s
  ", info[1], info[2], paste0(info[3], info[4]))
  res <- try(dbGetQuery(conn, sql), silent = TRUE)
  if(is.data.frame(res) && nrow(res) > 0)
    next
  
  # download file
  url <- paste0("https://data.binance.vision/", key)
  temp <- tempfile()
  download.file(url, temp, quiet = TRUE)
  if(!file.size(temp)) next
  file <- unzip(temp, exdir = tempdir())
  
  # read file
  x <- fread(
    file, 
    select = c(1:6, 9), 
    col.names = c(
      "TIMESTAMP", 
      "OPEN", 
      "HIGH", 
      "LOW", 
      "CLOSE",
      "VOLUME",
      "NUMTRD"
    ),
    key = c(
      "TIMESTAMP"
    )
  )
  
  # free up disk space
  unlink(temp)
  unlink(file)
  
  # skip if less than 3 observations
  if(nrow(x) < 3)
    next
  
  # convert to xts object
  x$TIME <- as.POSIXct(x$TIMESTAMP / 1000, origin = "1970-01-01", tz = "UTC")
  ts <- xts(x[,2:5], order.by = x$TIME)
  
  # compute estimates
  df <- data.frame(
    "SYMBOL" = info[1],
    "YYYYMM" = as.integer(paste0(info[3], info[4])),
    "FREQ" = info[2],
    "NUMTRD" = sum(x$NUMTRD),
    "PRC" = x$CLOSE[nrow(x)],
    "VOL" = sum(x$VOLUME),
    "PRCVOL" = sum(x$CLOSE * x$VOLUME),
    "SDRET" = sd(x$CLOSE[-1] / shift(x$CLOSE, 1)[-1]),
    spread(ts, method = c("EDGE", "AR", "CS", "ROLL"), sign = TRUE)
  )
  
  # save estimates
  dbWriteTable(conn, name = "mth", value = df, append = TRUE)
  
}

# Read estimates
x <- dbReadTable(conn, name = "mth")

# Close database connection
dbDisconnect(conn)

# Export
swrite(x, file = "bmd_mth.csv.gz", key = c("SYMBOL", "YYYYMM", "FREQ"))
