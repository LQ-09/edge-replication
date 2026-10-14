script_744925 <- function(
    data,        # path to data file
    benchmark,   # benchmark spread
    methods,     # vector of estimators
    ggoptions,   # figure options
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>%
    dplyr::rename(
      BENCHMARK = !!as.name(benchmark)
    ) %>%
    dplyr::select_at(
      c("YYYYMM", "BENCHMARK", methods)
    ) %>%
    tidyr::drop_na(
      .
    ) %>%
    tidyr::pivot_longer(
      cols = tidyr::all_of(methods), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::mutate(
      ESTIMATE = pmax(0, ESTIMATE),
    ) %>%
    dplyr::group_by(
      YYYYMM, 
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      COR = cor(ESTIMATE, BENCHMARK),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = methods)
    )
  
  fig <- ggplot(df, aes(
      x = as.Date(YYYYMM), 
      y = COR
    )) +
    geom_line(aes(
      linetype = ESTIMATOR, 
      color = ESTIMATOR
    )) +
    scale_y_continuous(
      labels = scales::percent
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
      x = "",
      y = "Correlation",
      color = "Estimator",
      linetype = "Estimator"
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
