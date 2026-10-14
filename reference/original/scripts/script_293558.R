script_293558 <- function(
    data,        # path to data file
    methods,     # vector of estimators
    ggoptions,   # figure options
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>%
    dplyr::select_at(
      c("SYMBOL", "YYYYMM", "FREQ", methods)
    ) %>%
    tidyr::drop_na(
      .
    ) %>%
    tidyr::pivot_longer(
      cols = dplyr::all_of(methods), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::group_by(
      SYMBOL,
      YYYYMM,
      ESTIMATOR
    ) %>%
    dplyr::mutate(
      N = dplyr::n()
    ) %>%
    dplyr::filter(
      N == 3
    ) %>%
    dplyr::group_by(
      YYYYMM,
      ESTIMATOR,
      FREQ
    ) %>%
    dplyr::summarise(
      ESTIMATE = mean(pmax(0, ESTIMATE)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = methods)
    )
    
    fig <- ggplot(df, aes(
      x = as.Date(YYYYMM), 
      y = ESTIMATE
    )) +
    facet_wrap(
      . ~ ESTIMATOR
    ) +
    geom_line(aes(
      color = FREQ
    )) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_color_manual(
      values = ggoptions$colors$freq,
      labels = ggoptions$labels$freq
    ) +
    labs(
      x = "",
      y = "Bid-Ask Spread",
      color = "Frequency"
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
