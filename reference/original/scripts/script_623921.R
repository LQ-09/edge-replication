script_623921 <- function(
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
    dplyr::filter(
      ESTIMATE < 0
    ) %>%
    dplyr::group_by(
      ESTIMATOR
    ) %>%
    dplyr::summarise(
      N = dplyr::n(),
      COR1 = cor(ESTIMATE, -BENCHMARK) * 100,
      COR2 = cor(ESTIMATE, -BENCHMARK, method = "spearman") * 100
    ) %>%
    tidyr::pivot_longer(
      cols = -1, 
      names_to = "VALUE"
    ) %>%
    tidyr::pivot_wider(
      names_from = "ESTIMATOR"
    ) %>%
    dplyr::select_at(
      c("VALUE", methods)
    )
    
  textab(
    df, 
    include.rownames = FALSE, 
    file = paste0(outprefix, ".tex")
  )
  
}
