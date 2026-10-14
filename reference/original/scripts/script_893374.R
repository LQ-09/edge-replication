script_893374 <- function(
    data,        # path to data file
    benchmark,   # benchmark spread
    ggoptions,   # figure options
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>%
    dplyr::mutate(
      S = !!as.name(benchmark),
      lnS = log(S)
    ) %>%
    dplyr::select(
      c("S", "lnS")
    ) %>%
    tidyr::pivot_longer(
      cols = c("S", "lnS"),
      names_to = "TYPE",
      values_to = "VALUE"
    ) %>%
    dplyr::mutate(
      TYPE = factor(
        TYPE, 
        levels = c("S", "lnS"), 
        labels = c("Spread", "Log-Spread")
      )
    )
    
  fig <- ggplot(df, aes(
      x = VALUE
    )) +
    facet_wrap(
      . ~ TYPE, 
      scales = "free"
    ) +
    geom_histogram(
      bins = 200
    ) +
    scale_y_continuous(
      labels = scales::comma
    ) + 
    labs(
      x = "Bid-Ask Spread",
      y = "Count"
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
