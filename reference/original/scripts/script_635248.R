script_635248 <- function(
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
      HJ = dplyr::na_if(HJ, YYYYMM < 199401),
      YYYY = YYYYMM %/% 100,
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
      c("KYPERMNO", "YYYY", "SIZE", "HJ", methods)
    ) %>%
    tidyr::pivot_longer(
      cols = tidyr::all_of(c("HJ", methods)), 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::group_by(
      KYPERMNO, 
      YYYY, 
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      SIZE = dplyr::last(SIZE),
      ESTIMATE_M = sqrt(mean(pmax(0, ESTIMATE)^2)), 
      ESTIMATE_Y = sqrt(pmax(0, mean(ESTIMATE * abs(ESTIMATE)))),
      .groups = "drop"
    ) %>%
    dplyr::group_by(
      SIZE, 
      YYYY, 
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      ESTIMATE_M = mean(ESTIMATE_M),
      ESTIMATE_Y = mean(ESTIMATE_Y),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      ESTIMATOR = factor(ESTIMATOR, levels = rev(c("HJ", methods)))
    )
  
  fig <- ggplot(df, aes(
      x = as.Date(as.integer(YYYY * 100 + 01))
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
      y = ESTIMATE_M,
      linetype = "M", 
      color = ESTIMATOR
    )) +
    geom_line(aes(
      y = ESTIMATE_Y,
      linetype = "Y", 
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
      values = ggoptions$linetypes$sample,
      labels = ggoptions$labels$sample,
      guide = guide_legend(reverse = TRUE)
    ) +
    labs(
      x = "",
      y = "Bid-Ask Spread",
      color = "Estimator",
      linetype = "Sample"
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
      y = -0.004, 
      data = data.frame(SIZE = 3),
      size = 3
    ) +
    geom_text(
      label = "CRSP-TAQ Merged Sample",
      x = as.Date(200709L), 
      y = -0.004, 
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
