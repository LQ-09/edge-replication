# 作者原始项目与参考表

`original/` 保存用户提供的 `dataverse_files.zip` 完整内容，保持作者文件原样。这里顶层的 `tab_2A.tex`、`tab_2B.tex`、`script_836294.R` 是供本仓库模拟验证使用的副本。

此前这里只放了部分文件，却沿用完整项目的说明，导致按 `renv::restore()` / `main.R` 操作时缺少脚本及环境启动文件。现在完整目录已补齐。

## 两个入口分别恢复

只复现已验证的 Table 2，请在仓库根目录按根 [README](../README.md) 运行。无需恢复作者的全部 75 个包。

运行作者完整项目时，进入 `reference/original/` 恢复其独立环境。`main.R` 使用相对路径，不要在仓库根目录运行它。已有 R 4.2.3 和编译工具时按下面步骤操作。本次 Apple Silicon + Conda 验证还需要[两项兼容配置](../docs/dependencies.md)，相关错误的处理已记录。

```sh
cd reference/original
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript -e 'library(eguidotti); library(magrittr); library(ggplot2); invisible(lapply(list.files("scripts", full.names = TRUE), source)); stopifnot(file.exists("input/stocks.csv"), file.exists("input/cryptos.csv")); cat("Original entry dependencies loaded\n")'
# 下面默认使用原包的随机占位数据；真实实证须先替换为授权真实数据。
Rscript main.R
```

`eguidotti` 是作者 GitHub `eguidotti/r` 上的包；`magrittr`、`ggplot2` 等来自 CRAN。`original/renv.lock` 记录了版本与源码位置；restore 安装它们，不需要同名文件放在 main.R 旁边。restore 不会补出缺失的 `scripts/` 或研究数据，这些必须随源项目提供。

**原包的两个 input CSV 是随机占位数据，不是论文真实数据。** 可以用于检查流程，不能据此声称重现真实市场结论。获取及生成真实输入的方法见 [作者 README](original/README.md)。未加入任何本地凭据或 WRDS 授权提取数据。
