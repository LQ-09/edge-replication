script_769420 <- function(
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
      !is.na(SIZE), 
      !is.na(HJ) | YYYYMM < min(YYYYMM[!is.na(HJ)]),
      complete.cases(.[,methods])
    ) %>%
    dplyr::select_at(
      c("YYYYMM", "SIZE", "HJ", "QS", methods)
    ) %>%
    tidyr::pivot_longer(
      cols = tidyr::all_of(c("HJ", "QS", methods)), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::group_by(
      SIZE, 
      YYYYMM, 
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      ESTIMATE = mean(pmax(0, ESTIMATE), na.rm = TRUE), 
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = rev(c("HJ", methods, "QS")))
    )

  fig <- ggplot(df, aes(
      x = as.Date(YYYYMM), 
      y = ESTIMATE, 
    )) +
    facet_wrap(
      . ~ SIZE,
      scales = "free_y",
      ncol = 1, 
      labeller = as_labeller(ggoptions$labels$size)
    ) +
    geom_vline(
      xintercept = as.Date(199305L), 
      colour = "#000000", 
      linetype = "aa",
      linewidth = 0.2
    ) +
    geom_line(aes(
      linetype = ESTIMATOR, 
      color = ESTIMATOR
    )) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_color_manual(
      values = ggoptions$colors$methods,
      labels = ggoptions$labels$methods,
      guide = guide_legend(reverse = TRUE)
    ) +
    scale_linetype_manual(
      values = ggoptions$linetypes$methods,
      labels = ggoptions$labels$methods,
      guide = guide_legend(reverse = TRUE)
    ) +
    labs(
      x = "",
      y = "Bid-Ask Spread",
      color = "Estimator",
      linetype = "Estimator"
    ) +
    geom_segment(
      x = as.Date(192601L), 
      xend = as.Date(199212L), 
      y = -Inf, 
      yend = -Inf,
      arrow = arrow(ends = "both", length = unit(0.2, "cm")),
      data = data.frame(SIZE = 3),
      linewidth = 0.2
    ) +
    geom_segment(
      x = as.Date(199310L), 
      xend = as.Date(202112L), 
      y = -Inf, 
      yend = -Inf,
      arrow = arrow(ends = "both", length = unit(0.2, "cm")),
      data = data.frame(SIZE = 3),
      linewidth = 0.2
    ) +
    geom_text(
      label = "CRSP Sample",
      x = as.Date(195912L), 
      y = -0.01, 
      data = data.frame(SIZE = 3),
      size = 3
    ) +
    geom_text(
      label = "CRSP-TAQ Merged Sample",
      x = as.Date(200709L), 
      y = -0.01, 
      data = data.frame(SIZE = 3),
      size = 3
    ) +
    coord_cartesian(
      clip = "off"
    ) +
    ggoptions$theme()
  
  ggsave(
    filename = paste0(outprefix, ".pdf"), 
    plot = fig, 
    width = ggoptions$export$width, 
    height = ggoptions$export$height * 1.5, 
    units = ggoptions$export$units
  )

}
