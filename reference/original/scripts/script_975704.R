script_975704 <- function(
    data,        # path to data file
    fun,         # evaluation metric f(estimates, benchmark) 
    max,         # max metric is better
    benchmark,   # benchmark spread
    methods,     # vector of estimators
    outprefix    # prefix to save output
){
  
  x <- fread(data, verbose = FALSE)
  
  df <- x %>%
    dplyr::rename(
      BENCHMARK = !!as.name(benchmark)
    ) %>%
    dplyr::select_at(
      c("KYPERMNO", "YYYYMM", "EXCHCD", "ME", "NUMTRD", "BENCHMARK", methods)
    ) %>%
    tidyr:::drop_na(
      .
    ) %>%
    dplyr::group_by(
      KYPERMNO
    ) %>%
    dplyr::arrange(
      YYYYMM
    ) %>%
    dplyr::mutate(
      SPREADAVG = mean(BENCHMARK),
      NUMTRDAVG = mean(NUMTRD),
      TCAPEND = dplyr::last(ME)
    ) %>%
    dplyr::ungroup(
      .
    ) %>%
    dplyr::mutate(
      TCAP5 = ntile(TCAPEND, 5),
      SPREAD5 = ntile(SPREADAVG, 5),
      NUMTRD5 = ntile(NUMTRDAVG, 5),
      PERIOD = cut(
        YYYYMM, 
        right = FALSE, 
        breaks = c(199301, 199701, 200101, 200301, 200801, 201201, 201601, Inf)
      )
    )
    
  stats <- function(df, by){
    df %>%
      dplyr::select_at(
        c(by, "BENCHMARK", methods)
      ) %>%
      dplyr::mutate_at(
        by, 
        factor
      ) %>%
      tidyr::pivot_longer(
        cols = tidyr::all_of(methods), 
        names_to = "ESTIMATOR", 
        values_to = "ESTIMATE"
      ) %>%
      dplyr::mutate(
        ESTIMATOR = factor(ESTIMATOR, levels = methods),
        ESTIMATE = pmax(0, ESTIMATE)
      ) %>%
      dplyr::group_by_at(
        c(by, "ESTIMATOR")
      ) %>%
      dplyr::summarise(
        VALUE = fun(ESTIMATE, BENCHMARK),
        .groups = "drop"
      ) %>%
      tidyr::pivot_wider(
        id_cols = dplyr::all_of(by), 
        names_from = "ESTIMATOR", 
        values_from = "VALUE"
      ) 
  }
  
  textab(
    stats(df, by = "EXCHCD"), 
    bold.each = "row", 
    bold.max = max,
    include.rownames = FALSE, 
    file = paste0(outprefix, "A.tex")
  )

  textab(
    stats(df, by = "PERIOD"), 
    bold.each = "row", 
    bold.max = max,
    include.rownames = FALSE, 
    file = paste0(outprefix, "B.tex")
  )
  
  textab(
    stats(df, by = "TCAP5"), 
    bold.each = "row", 
    bold.max = max,
    include.rownames = FALSE, 
    file = paste0(outprefix, "C.tex")
  )
  
  textab(
    stats(df, by = "SPREAD5"), 
    bold.each = "row", 
    bold.max = max,
    include.rownames = FALSE, 
    file = paste0(outprefix, "D.tex")
  )
  
  textab(
    stats(df, by = "NUMTRD5"), 
    bold.each = "row", 
    bold.max = max,
    include.rownames = FALSE, 
    file = paste0(outprefix, "E.tex")
  )
  
}
