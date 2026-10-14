script_836294 <- function(
    units,        # units of time periods
    nsim,         # number of simulations
    nobs,         # number of periods to estimate the spread
    trades,       # number of trades per period
    prob,         # probability to observe a trade
    volatility,   # volatility of open-to-close returns
    overnight,    # volatility of close-to-open returns
    spreads,      # vector of spreads to use in simulations
    methods,      # vector of methods to estimate the spread
    seed,         # seed to initialize random numbers
    outprefix     # prefix to save output
){
  
  set.seed(seed)
  
  x <- lapply(spreads, function(spread){
    
    ohlc <- bidask::sim(
      n = nsim * nobs, 
      trades = trades, 
      prob = prob, 
      spread = spread, 
      volatility = volatility, 
      overnight = overnight,
      units = tolower(units)
    )
    
    s <- bidask::spread(
      x = ohlc, 
      width = seq(0, nrow(ohlc), by = nobs), 
      method = methods, 
      sign = TRUE
    )
    
    s[s<0] <- 0
    
    data.frame(rbind(
      apply(s, 2, mean), 
      apply(s, 2, sd), 
      apply(s==0, 2, mean)
    ))
    
  })
  
  df <- x %>%
    dplyr::bind_rows(
      .
    ) %>%
    dplyr::mutate(
      SPREAD = rep(spreads, each = 3)
    ) %>%
    dplyr::mutate_all(function(x) {
      sprintf("%.2f", x*100)
    }) %>%
    dplyr::mutate(
      TYPE = rep(c("Mean", "Sd", "Zero"), length.out = dplyr::n())
    ) %>%
    dplyr::select_at(
      c("SPREAD", "TYPE", methods)
    )
  
  textab(
    df, 
    include.rownames = FALSE, 
    file = paste0(outprefix, ".tex")
  )
  
}
