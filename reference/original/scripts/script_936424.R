script_936424 <- function(
    units,        # units of time periods
    nobs,         # number of periods to estimate the spread
    trades,       # number of trades per period
    probs,        # vector of probabilities to observe a trade
    volatility,   # volatility of open-to-close returns
    overnight,    # volatility of close-to-open returns
    spread,       # spread to use in simulation
    methods,      # vector of methods to estimate the spread
    seed,         # seed to initialize random numbers
    ggoptions,    # figure options
    outprefix     # prefix to save output
){
  
  set.seed(seed)
  
  x <- lapply(probs, function(prob){
    
    ohlc <- bidask::sim(
      n = nobs, 
      trades = trades, 
      prob = prob, 
      spread = spread, 
      volatility = volatility, 
      overnight = overnight,
      units = tolower(units)
    )
    
    bidask::spread(
      x = ohlc, 
      method = methods,
      sign = TRUE
    )
    
  })
  
  df <- x %>%
    dplyr::bind_rows(
      .
    ) %>%
    dplyr::mutate(
      TRADES = probs * trades,
    ) %>%
    tidyr::pivot_longer(
      cols = -tidyr::one_of("TRADES"), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = methods),
      ESTIMATE = pmax(0, ESTIMATE)
    )

  fig <- ggplot(df, aes(
      x = TRADES, 
      y = ESTIMATE
    )) +
    geom_hline(
      yintercept = spread, 
      linetype = 5
    ) +
    geom_line(aes(
      linetype = ESTIMATOR, 
      color = ESTIMATOR
    )) +
    geom_point(aes(
      shape = ESTIMATOR, 
      color = ESTIMATOR
    ), size = 4) +
    scale_x_continuous(
      trans = 'log10'
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
      x = sprintf("Average Number of Trades per %s", units),
      y = "Bid-Ask Spread",
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
