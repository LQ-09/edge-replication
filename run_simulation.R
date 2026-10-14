# Reproduce Table 2A/2B using the authors' pinned bidask implementation.
# Computation follows reference/script_836294.R; only output formatting changes.
options(warn = 1)
stopifnot(getRversion() == "4.2.3",
          packageVersion("bidask") == "2.0.0",
          packageVersion("xts") == "0.13.1",
          packageVersion("zoo") == "1.8.12")
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)])
setwd(dirname(normalizePath(script)))
dir.create("results", showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), "results/sessionInfo.txt")
write.csv(installed.packages()[c("bidask", "xts", "zoo"), c("Package", "Version")],
          "results/package_versions.csv", row.names = FALSE)
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
methods <- c("EDGE", "OHLC", "CHLO", "OHL", "CHL", "AR", "CS", "ROLL")
spreads <- c(0.005, 0.01, 0.03, 0.05, 0.08)
nsim <- 10000L
nobs <- 21L

# Independent scalar/vectorized EDGE agreement, including sparse-trading data.
set.seed(321)
test_x <- bidask::sim(n = 210, prob = 0.01)
test_s <- bidask::spread(test_x, width = seq(0, 210, 21), sign = TRUE)
ends <- seq(21, 210, 21)
scalar <- vapply(seq_along(ends), function(i) {
  # The original vectorized method shares the preceding close across blocks.
  start <- if (i == 1L) 1L else ends[i-1L]
  x <- test_x[start:ends[i], ]
  bidask::edge(x$Open, x$High, x$Low, x$Close, sign = TRUE)
}, numeric(1))
stopifnot(isTRUE(all.equal(as.numeric(test_s), scalar, tolerance = 1e-10)))
stopifnot(isTRUE(all.equal(abs(as.numeric(test_s)),
  as.numeric(bidask::spread(test_x, width = seq(0, 210, 21))), tolerance = 1e-10)))
cat("Self-check passed: scalar/vectorized EDGE and signed/absolute conventions.\n")

all_results <- list()
started <- Sys.time()
for (panel in c("A", "B")) {
  prob <- if (panel == "A") 1 else 0.01
  set.seed(123)
  for (true_spread in spreads) {
    cat(sprintf("Panel %s, spread %.1f%%: simulating %d months...\n",
                panel, 100 * true_spread, nsim))
    ohlc <- bidask::sim(n = nsim * nobs, trades = 390, prob = prob,
                       spread = true_spread, volatility = 0.03,
                       overnight = 0, units = "day")
    prices <- as.matrix(ohlc)
    stopifnot(nrow(prices) == nsim*nobs, all(is.finite(prices)), all(prices > 0),
              all(prices[,2] >= pmax(prices[,1], prices[,4])),
              all(prices[,3] <= pmin(prices[,1], prices[,4])))
    s <- bidask::spread(x = ohlc, width = seq(0, nrow(ohlc), by = nobs),
                        method = methods, sign = TRUE)
    stopifnot(nrow(s) == nsim, all(is.finite(s)))
    s[s < 0] <- 0
    estimates <- as.matrix(s)
    saveRDS(estimates, sprintf("results/draws_%s_%04dbps.rds", panel, round(true_spread*10000)))
    for (method in methods) {
      values <- estimates[,method]
      all_results[[length(all_results)+1L]] <- data.frame(
        panel = panel, trade_probability = prob, true_spread = true_spread,
        method = method, n_months = length(values), mean = mean(values),
        sd = sd(values), zero_fraction = mean(values == 0),
        mean_mcse = sd(values)/sqrt(length(values)))
    }
    write.csv(do.call(rbind, all_results), "results/simulation_results.csv", row.names = FALSE)
    rm(ohlc, prices, s, estimates)
    invisible(gc())
  }
}
results <- do.call(rbind, all_results)
comparison <- list()
for (panel in c("A", "B")) {
  lines <- readLines(sprintf("reference/tab_2%s.tex", panel))
  lines <- lines[grepl("^\\s*[0-9]", lines)]
  stopifnot(length(lines) == 15L)
  for (line in lines) {
    fields <- trimws(strsplit(gsub("\\\\", "", line), "&", fixed = TRUE)[[1]])
    stopifnot(length(fields) == 10L)
    true_spread <- as.numeric(fields[1])/100
    metric <- c(Mean = "mean", Sd = "sd", Zero = "zero_fraction")[[fields[2]]]
    ref_values <- as.numeric(fields[3:10])
    for (j in seq_along(methods)) {
      row <- results[results$panel == panel & results$true_spread == true_spread &
                     results$method == methods[j], ]
      stopifnot(nrow(row) == 1L)
      actual <- row[[metric]] * 100
      comparison[[length(comparison)+1L]] <- data.frame(
        panel = panel, true_spread_pct = true_spread*100, method = methods[j],
        metric = fields[2], reference_pct = ref_values[j], reproduced_pct = actual,
        rounded_pct = round(actual, 2), difference_pp = actual-ref_values[j],
        matches_published_precision = abs(round(actual,2)-ref_values[j]) < 1e-9)
    }
  }
}
comparison <- do.call(rbind, comparison)
write.csv(comparison, "results/reference_comparison.csv", row.names = FALSE)
stopifnot(nrow(results) == 80L, nrow(comparison) == 240L)
matched <- sum(comparison$matches_published_precision)
writeLines(c(sprintf("Matching cells at the supplied reference precision: %d / %d", matched, nrow(comparison)),
             sprintf("Elapsed seconds: %.1f", as.numeric(difftime(Sys.time(), started, units = "secs"))),
             "Reference: user-provided archive output/tab_2A.tex and output/tab_2B.tex.",
             "No pseudo empirical input data were used."), "results/validation.txt")
cat(readLines("results/validation.txt"), sep = "\n")
writeLines(capture.output(sessionInfo()), "results/sessionInfo.txt")
print(results[results$true_spread == 0.01 & results$method == "EDGE", ])
if (matched != nrow(comparison)) warning("Some displayed cells differ; inspect reference_comparison.csv.")
