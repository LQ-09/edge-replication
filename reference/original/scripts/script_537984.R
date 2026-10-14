script_537984 <- function(
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
    dplyr::group_by(
      KYPERMNO
    ) %>%
    dplyr::arrange(
      YYYYMM
    ) %>%
    dplyr::mutate(
      TCAPEND = dplyr::last(ME)
    ) %>%
    dplyr::ungroup(
      .
    ) %>%
    dplyr::select_at(
      c("BENCHMARK", "TCAPEND", methods)
    ) %>%
    tidyr::drop_na(
      .
    ) %>%
    dplyr::mutate(
      DECILE = ntile(TCAPEND, n = 10)
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
      DECILE, 
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
      x = DECILE, 
      y = COR
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
      breaks = 1:10
    ) +
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
    scale_shape_manual(
      values = ggoptions$shapes$methods,
      labels = ggoptions$labels$methods
    ) +
    labs(
      x = "Size Deciles",
      y = "Correlation",
      color = "Estimator",
      linetype = "Estimator",
      shape = "Estimator"
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
