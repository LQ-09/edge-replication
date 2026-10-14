library(here)
library(eguidotti)


# Data tables
tables <- list(
  
  "{data}/source/binance/202302" = c(
    "bmd_mth.csv.gz"
  )
  
)

# Set path to data
data <- Sys.getenv("DATA")
names(tables) <- gsub("{data}", data, names(tables), fixed = TRUE)

# Read
x <- fread(paste(names(tables[1]), tables[[1]][1], sep = "/"))

# Subset
x <- x[YYYYMM <= 202112]

# Export
file <- here("input", "cryptos.csv")
file.remove(file)
swrite(x, file = file, key = c("SYMBOL", "YYYYMM", "FREQ"))
