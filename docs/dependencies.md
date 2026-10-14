# 依赖与源码完整性检查（2026-10-14）

## 原因

此前 `reference/` 只保存作者项目的片段，却保留了原 README 中 `renv::restore()` 和 `main.R` 的运行说明。缺失的 `.Rprofile`、`renv/activate.R`、16 个 `scripts/` 文件和 `input/` 使原版入口无法按说明运行。这是仓库打包不完整，已修复。

`library(eguidotti)`、`library(magrittr)`、`library(ggplot2)` 加载已安装的 R 包，不是在当前目录寻找同名 `.R` 文件。作者的 `renv.lock` 已记录包版本及来源：`eguidotti` 来自 GitHub `eguidotti/r` 的固定提交，其他多数包来自 CRAN。环境管理工具叫 `renv`；Python 的 `venv` 不适用于此项目。

## 已补齐的内容

- `reference/original/`：原 ZIP 中全部 116 个文件，逐字节与原包核对一致；main.R 引用的 16 个脚本均存在。作者文件未改写。
- 根 `.Rprofile`、`renv/activate.R`、`renv/settings.json`、`renv.lock`：Table 2 专用项目，锁定 renv、bidask、xts、zoo，以及 zoo 必需的间接依赖 lattice，避免依赖本机预装包。
- 根 `.renvignore`：排除归档项目和 vendor，避免根环境扫描误混入作者完整项目的 75 包依赖。
- `run_simulation.R --check-only`：只执行版本检查和小样本 EDGE 自检，不覆盖已有模拟结果。

## Table 2 专用入口：通过

在工作副本的独立项目包库中移除 bidask/xts/zoo 安装链接后，通过 `renv::restore(prompt = FALSE, rebuild = TRUE)` 下载并从源码重建三个计算包。确认实际加载的是该项目自己的包库，版本为 R 4.2.3、bidask 2.0.0、xts 0.13.1、zoo 1.8-12，bidask 的 RemoteSha 与作者锁定提交完全一致。

另外独立恢复并确认 lattice 0.20-45，五个锁定依赖均就绪。

随后运行 README 的 `Rscript run_simulation.R --check-only`，标量/向量化 EDGE 与符号处理检查通过；比较前后校验值，15 个已保存结果文件均未改变。根依赖扫描未包含 eguidotti、magrittr、ggplot2 等归档项目依赖。

原有完整模拟的 240/240 展示精度对照仍然有效。本次没有改变数据生成、参数或估计公式，因此没有重复运行全部 100,000 个模拟窗口。

## 作者完整项目：验证记录

完整依赖恢复及小样本集成检查通过，使用下节记录的两项 Apple Silicon + Conda 兼容配置：

- 75/75 个作者锁定包版本均核对一致（按 R 的版本号语义比较）；72 个包恢复到独立测试库，另外 3 个包复用已有匹配版本。
- `library(eguidotti)`、`library(magrittr)`、`library(ggplot2)` 加载成功。
- 作者 16 个 scripts 均成功加载，main.R 中引用的函数全部存在，两个随机占位输入存在。
- 直接调用作者原始 `script_836294`，运行 10 个 21 日窗口、4 种估计方法，成功生成包含 Mean/Sd/Zero 的 LaTeX 表格，验证了从包加载到表格导出的执行链。

没有运行完整 main.R；以上不能解释为全部论文结果已重新验证。

## 边界

验证平台为 Apple Silicon macOS、Conda R 4.2.3。未在 Windows/Linux 测试。原包的两个 input CSV 是随机占位数据；未运行真实市场实证，也未声称完整论文所有图表已经重现。

## Apple Silicon + Conda 的旧工具链兼容配置

以下只针对本次检查遇到的 Conda R 4.2.3 环境；原生 R、其他平台不要直接套用。本次遇到两处外部工具链不兼容：

1. R 的 Makeconf 指向 gfortran 13.3.0，但环境安装的是 13.4.0，导致 `ld: library not found for -lheapt_w`。
2. 锁定的 R `curl` 5.0.0 使用新版 libcurl 头文件生成了不合法的 R option 表。改用 libcurl 7.88.1 的头文件可完成构建，不升级作者的 R 包或修改其代码。

如果在此环境遇到上述错误，激活 Conda 环境，进入 `reference/original/` 后执行下列配置。文件仅写入被 Git 忽略的 `.dependency-build/`，环境变量仅影响本次 R 进程。

```sh
sh -eu <<'SH'
mkdir -p .dependency-build
curl -fL https://curl.se/download/curl-7.88.1.tar.gz -o .dependency-build/curl-7.88.1.tar.gz
printf '%s\n' 'cdb38b72e36bc5d33d5b8810f8018ece1baa29a8f215b4495e495ded82bbf3c7  .dependency-build/curl-7.88.1.tar.gz' | shasum -a 256 -c -
tar -xzf .dependency-build/curl-7.88.1.tar.gz -C .dependency-build
Rscript - <<'RS'
stopifnot(Sys.info()[['sysname']] == 'Darwin', getRversion() == '4.2.3')
prefix <- normalizePath(file.path(R.home(), '../..'))
heapt <- list.files(file.path(prefix, 'lib/gcc'), pattern = '^libheapt_w[.]a$',
                    recursive = TRUE, full.names = TRUE)
stopifnot(length(heapt) == 1L)
makevars <- file.path(normalizePath('.dependency-build'), 'Makevars')
writeLines(sprintf('FLIBS = -L%s -lheapt_w -L%s -lgfortran -lquadmath -lm',
                   shQuote(dirname(heapt)), shQuote(file.path(prefix, 'lib'))), makevars)
Sys.setenv(R_MAKEVARS_USER = makevars)
headers <- normalizePath('.dependency-build/curl-7.88.1/include')
options(configure.vars = c(curl = paste('INCLUDE_DIR=', shQuote(headers),
  ' LIB_DIR=', shQuote(file.path(prefix, 'lib')), sep = '')))
renv::restore(prompt = FALSE)
RS
SH
```

这里根据实际 `libheapt_w.a` 位置生成 Fortran 链接路径，不硬编码编译器小版本。若搜索结果不唯一，代码会停止；应检查实际工具链，而不是随便选一个路径。
