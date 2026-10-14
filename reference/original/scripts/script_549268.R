script_549268 <- function(
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
    
    data.frame(
      SPREAD = spread,
      STD = apply(s, 2, sd),
      ESTIMATOR = methods
    )
    
  })
  
  df <- x %>% 
    dplyr::bind_rows(
      .
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = methods)
    )
  
  fig <- ggplot(df, aes(
      x = SPREAD, 
      y = STD
    )) +
    geom_line(aes(
      linetype = ESTIMATOR, 
      color = ESTIMATOR
    )) +
    geom_point(aes(
      shape = ESTIMATOR, 
      color = ESTIMATOR
    ), size = 4) +
    scale_x_continuous(
      labels = scales::percent, 
      n.breaks = 8
    ) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_shape_manual(
      values = ggoptions$shapes$methods,
      labels = ggoptions$labels$methods
    ) +
    scale_color_manual(
      values = ggoptions$colors$methods,
      labels = ggoptions$labels$methods
    ) +
    scale_linetype_manual(
      values = ggoptions$linetypes$methods,
      labels = ggoptions$labels$methods
    ) +
    labs(
      x = "Bid-Ask Spread",
      y = "Standard Deviation",
      linetype = "Estimator",
      shape = "Estimator",
      color = "Estimator"
    ) +
    ggoptions$theme()
  
  ggsave(
    filename = paste0(outprefix, ".pdf"), 
    plot = fig, 
    width = ggoptions$export$width, 
    height = ggoptions$export$height, 
    units = ggoptions$export$units
  )
  
}
