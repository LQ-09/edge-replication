script_137638 <- function(
    data,        # path to data file
    methods,     # vector of estimators
    ggoptions,   # figure options
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>% 
    dplyr::group_by(
      YYYYMM
    ) %>%
    dplyr::mutate(
      SIZE = ntile(ME, n = c(0, 0.5, 0.8, 1))
    ) %>%
    dplyr::ungroup(
      .
    ) %>%
    dplyr::filter(
      SIZE == 3,
      complete.cases(.[,methods])
    ) %>%
    dplyr::select_at(
      c("YYYYMM", methods)
    ) %>%
    tidyr::pivot_longer(
      cols = tidyr::all_of(methods), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::group_by(
      YYYYMM, 
      ESTIMATOR
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
      y = ESTIMATE, 
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
      y = "Bid-Ask Spread",
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
