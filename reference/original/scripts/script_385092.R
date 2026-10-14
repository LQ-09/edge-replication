script_385092 <- function(
    data,        # path to data file
    benchmark,   # benchmark spread
    methods,     # vector of estimators
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>%
    dplyr::select_at(
      c(benchmark, methods)
    ) %>%
    dplyr::mutate(
      BENCHMARK = !!as.name(benchmark)
    ) %>%
    tidyr::drop_na(
      .
    ) %>%
    tidyr::pivot_longer(
      cols = -BENCHMARK, 
      names_to = "ESTIMATOR", 
      values_to = "ESTIMATE"
    ) %>%
    dplyr::mutate(
      POS = ESTIMATE > 0,
      ESTIMATE = pmax(0, ESTIMATE)
    ) %>%
    dplyr::group_by(
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      N = dplyr::n(),
      MEAN = mean(ESTIMATE),
      MEDIAN = median(ESTIMATE),
      SD = sd(ESTIMATE),
      COR1 = cor(ESTIMATE, BENCHMARK),
      COR2 = cor(ESTIMATE, BENCHMARK, method = "spearman"),
      MAPE = mape(log(ESTIMATE[POS]), log(BENCHMARK[POS])),
      RMSE = rmse(log(ESTIMATE[POS]), log(BENCHMARK[POS])),
      ZERO = mean(ESTIMATE == 0)
    ) %>%
    dplyr::mutate_at(
      c("MEAN", "MEDIAN", "SD", "COR1", "COR2", "MAPE", "ZERO"),
      function(x) sprintf("%.2f", x*100)
    )
    
  textab(
    df, 
    include.rownames = FALSE, 
    file = paste0(outprefix, ".tex")
  )
  
}
