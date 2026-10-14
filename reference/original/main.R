library(eguidotti)
library(magrittr)
library(ggplot2)


############################### SETUP ###############################

# Path to data files
data <- list(
  "stocks" = "input/stocks.csv",
  "cryptos" = "input/cryptos.csv"
)

# Load scripts
invisible(sapply(list.files("scripts", full.names = TRUE), source))

# Create output dir
output <- "output"
if(!dir.exists(output))
  dir.create(output)

# Figure options
ggoptions <- list(
  'theme' = function(...){
    theme_minimal() +
      theme(
        legend.position = "top",
        legend.key.width = unit(3, "line"),
        ...)
  },
  'export' = list(
    'width' = 19,
    'height' = 12,
    'units' = 'cm'
  ),
  'colors' = list(
    'size' = c(
      '1' = '#d62728',
      '2' = '#ff7f0e',
      '3' = '#1f77b4'
    ),
    'freq' = c(
      '1m' = '#d62728',
      '1h' = '#ff7f0e',
      '1d' = '#1f77b4'
    ),
    'methods' = c(
      'HJ' = "#111111",
      'QS' = "#666666",
      'EDGE' = '#1f77b4',
      'EDGECHL' = '#1f77b4',
      'AR' = '#ff7f0e',
      'CS' = '#d62728',
      'ROLL' = '#8c564b',
      'OHL' = '#e377c2',
      'CHL' = '#e377c2',
      'OHLC' = '#9467bd',
      'CHLO' = '#9467bd',
      'OHL.CHL.OHLC.CHLO' = '#17becf',
      'EDGEMS' = '#1f77b4'
    )
  ),
  'linetypes' = list(
    'sample' = c(
      'M' = 1,
      'Y' = 2
    ),
    'methods' = c(
      'HJ' = 1,
      'QS' = 3,
      'EDGE' = 1,
      'EDGECHL' = 1,
      'AR' = 1,
      'CS' = 1,
      'ROLL' = 1,
      'OHL' = 2,
      'CHL' = 2,
      'OHLC' = 2,
      'CHLO' = 2,
      'OHL.CHL.OHLC.CHLO' = 2,
      'EDGEMS' = 2
    )
  ),
  'shapes' = list(
    'methods' = c(
      'EDGE' = 19,
      'AR' = 17,
      'CS' = 15,
      'ROLL' = 18,
      'OHL' = 6,
      'CHL' = 4,
      'OHLC' = 5,
      'CHLO' = 3,
      'OHL.CHL.OHLC.CHLO' = 8
    )
  ),
  'labels' = list(
    'size' = c(
      '1' = 'Small',
      '2' = 'Mid',
      '3' = 'Large'
    ),
    'freq' = c(
      '1d' = 'Daily prices',
      '1h' = 'Hourly prices',
      '1m' = 'Minute prices'
    ),
    'sample' = c(
      'M' = 'Monthly',
      'Y' = 'Yearly'
    ),
    'methods' = c(
      'HJ' = 'HJ',
      'QS' = 'QS',
      'EDGE' = 'EDGE',
      'EDGECHL' = 'EDGE',
      'AR' = 'AR',
      'CS' = 'CS',
      'ROLL' = 'ROLL',
      'OHL' = 'OHL',
      'CHL' = 'CHL',
      'OHLC' = 'OHLC',
      'CHLO' = 'CHLO',
      'OHL.CHL.OHLC.CHLO' = 'GMM',
      'EDGEMS' = 'EDGE/HF'
    )
  )
)


######################## SIMULATION RESULTS #########################
print("Running simulations")

script_836294(
  units = "Day",
  nsim = 10000,
  nobs = 21,
  trades = 390,
  prob = 1,
  volatility = 0.03,
  overnight = 0,
  spreads = c(0.005, 0.01, 0.03, 0.05, 0.08),
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  seed = 123,
  outprefix = sprintf("%s/tab_2A", output)
)

script_836294(
  units = "Day",
  nsim = 10000,
  nobs = 21,
  trades = 390,
  prob = 0.01,
  volatility = 0.03,
  overnight = 0,
  spreads = c(0.005, 0.01, 0.03, 0.05, 0.08),
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  seed = 123,
  outprefix = sprintf("%s/tab_2B", output)
)

script_936424(
  units = "Day",
  nobs = 21 * 10000,
  trades = 390,
  probs = exp(seq(log(1/390), log(1), length.out = 15)),
  spread = 0.01,
  volatility = 0.03,
  overnight = 0,
  methods = c("EDGE", "AR", "CS"),
  seed = 123,
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_2", output)
)

script_549268(
  units = "Day",
  nsim = 10000,
  nobs = 21,
  trades = 390,
  prob = 1,
  volatility = 0.03,
  overnight = 0,
  spreads = c(0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08),
  methods = c("EDGE", "OHL.CHL.OHLC.CHLO", "AR", "CS", "OHL", "CHL", "OHLC", "CHLO"),
  seed = 123,
  outprefix = sprintf("%s/fig_3", output)
)


######################## EMPIRICAL RESULTS ##########################
print("Running empirical analysis")

script_019273(
  data = data$stocks, 
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_1", output)
)

script_385092(
  data = data$stocks, 
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_3", output)
)

script_385092(
  data = data$stocks, 
  benchmark = "HJ",
  methods = c("EDGE", "EDGEMS"),
  outprefix = sprintf("%s/sec_6.2", output)
)

script_623921(
  data = data$stocks, 
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.2", output)
)

script_893374(
  data = data$stocks, 
  benchmark = "HJ",
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_I.2", output)
)

script_744925(
  data = data$stocks, 
  benchmark = "HJ",
  methods = c("EDGE", "AR", "CS", "ROLL"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_4", output)
)

script_537984(
  data = data$stocks, 
  benchmark = "HJ",
  methods = c("EDGE", "AR", "CS", "ROLL"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_5", output)
)

script_975704(
  data = data$stocks, 
  fun = function(e, b) cor(e, b) * 100,
  max = TRUE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_4", output)
)

script_975704(
  data = data$stocks, 
  fun = function(e, b) cor(e, b, method = "spearman") * 100,
  max = TRUE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.4", output)
)

script_975704(
  data = data$stocks, 
  fun = function(e, b) mape(log(e[e>0]), log(b[e>0])) * 100,
  max = FALSE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.5", output)
)

script_975704(
  data = data$stocks, 
  fun = function(e, b) rmse(log(e[e>0]), log(b[e>0])),
  max = FALSE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.6", output)
)

script_975704(
  data = data$stocks, 
  fun = function(e, b) mean(e <= 0) * 100,
  max = FALSE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.7", output)
)

script_439163(
  data = data$stocks, 
  fun = function(e, b) cor(e, b) * 100,
  max = TRUE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.9", output)
)

script_679624(
  data = data$stocks, 
  fun = function(e, b) cor(e, b) * 100,
  max = TRUE,
  benchmark = "HJ",
  methods = c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL"),
  outprefix = sprintf("%s/tab_I.8", output)
)

script_769420(
  data = data$stocks, 
  methods = c("EDGECHL", "AR", "CS"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_6", output)
)

script_137638(
  data = data$stocks, 
  methods = c("HJ", "EDGE", "EDGEMS"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_7", output)
)

script_293558(
  data = data$cryptos, 
  methods = c("EDGE", "AR", "CS"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_8", output)
)

script_635248(
  data = data$stocks, 
  methods = c("EDGECHL"),
  ggoptions = ggoptions, 
  outprefix = sprintf("%s/fig_I.3", output)
)
