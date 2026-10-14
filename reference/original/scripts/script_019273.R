script_019273 <- function(
    data,        # path to data file
    ggoptions,   # figure options
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  x$FRAC <- rowMeans(
    x[,c("FRACOH", "FRACOL", "FRACCH", "FRACCL")], 
    na.rm = TRUE
  )
  
  x[, 
    SIZE := ntile(ME, c(0, 0.5, 0.8, 1)), 
    by = YYYYMM]
  
  df <- x[!is.na(SIZE), .(
    FRAC = mean(FRAC, na.rm = TRUE)), 
    by = .(YYYYMM, SIZE)]
  
  fig <- ggplot(df, aes(
      x = as.Date(YYYYMM), 
      y = FRAC
    )) +
    geom_line(aes(
      color = factor(SIZE)
    )) +
    scale_y_continuous(
      labels = scales::percent
    ) +
    scale_color_manual(
      values = ggoptions$colors$size, 
      labels = ggoptions$labels$size
    ) +
    labs(
      x = "",
      y = "Probability o/c=h/l",
      color = "Size"
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
