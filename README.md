# EDGE 模拟复现：Table 2A / 2B

复现日期：2026-10-14。对象为 Ardia, Guidotti & Kroencke (2024), *Efficient Estimation of Bid-Ask Spreads from Open, High, Low, and Close Prices*, Journal of Financial Economics 161, 103916。

## 本次范围

执行作者 Table 2 的完整两组模拟：频繁交易（A）与稀疏交易（B），每组包含 0.5%、1%、3%、5%、8% 五种真实价差，使用 EDGE、OHLC、CHLO、OHL、CHL、AR、CS、ROLL 八种方法。每个场景模拟 10,000 个连续的 21 日窗口，合计 100,000 个窗口、800,000 个估计值。

对照来源是用户提供的 `dataverse_files.zip` 内作者保存的 `output/tab_2A.tex` 和 `output/tab_2B.tex`，已原样保存在 `reference/`。这是对作者复现包所附表格的核对，未另外逐页核对出版商论文 PDF。

压缩包 README 明确指出 `input/stocks.csv` 和 `input/cryptos.csv` 是随机生成的占位数据。本次模拟不需要、也未读取这些文件；尚未完成 CRSP/TAQ 真实市场实证、财报事件或日内扩展。

## 方法与复现细节

- R 4.2.3；bidask 2.0.0；xts 0.13.1；zoo 1.8-12，与作者锁文件对应的核心计算版本一致。
- bidask 源码固定为提交 `2dbafe0087e609c7b153e1a43b7ce6c923daf89c`，完整 R 包源码保存在 `vendor/bidask/`。
- 每天 390 个潜在成交机会；A 的成交观察概率为 1，B 为 0.01（期望每天 3.9 次）；日内波动参数 0.03，隔夜波动 0，漂移 0。
- 每个面板重设随机种子 123，依次运行五种价差，不在价差之间重设种子。因此单独运行 1% 并设种子 123 不能逐值重现原表。
- 直接调用作者 `bidask::sim()` 和 `bidask::spread()`；使用原端点 `seq(0, nrow(ohlc), by=21)`、`sign=TRUE`，再把负估计归零。
- 保留作者端点与滞后价格的边界处理：第一个窗口有 20 个可用相邻日变化，后续窗口使用前一窗口末日的滞后价格。没有改成逐窗口独立重新生成价格。
- `run_simulation.R` 将原脚本的数据生成和估计逻辑保留，表格导出改为基础 R，以免为排版安装与计算无关的依赖。
- 均值和标准差的底层存储单位为小数（0.01 = 1%）。零值比例也存为 0–1。对照表乘以 100，保留作者两位小数；Mean/Sd 列为百分比价差，Zero 列为样本占比百分数。

## 文件

| 文件 | 内容 |
|---|---|
| `RESULTS.md` | 结果摘要与 1% 场景对照 |
| `run_simulation.R` | 可独立运行的模拟入口与自检 |
| `results/simulation_results.csv` | 80 行完整精度统计结果，含模拟均值的 Monte Carlo 标准误 |
| `results/reference_comparison.csv` | 240 个对照单元格：均值、标准差、零值比例 |
| `results/draws_*.rds` | 10 个场景各 10,000 × 8 的归零后估计矩阵 |
| `results/validation.txt` | 对照通过数与运行耗时 |
| `results/sessionInfo.txt`、`package_versions.csv` | 实际计算环境 |
| `run.log` | 本次运行日志 |
| `reference/` | 作者原始主程序、模拟脚本、说明、锁文件及参考表 |
| `SHA256SUMS.txt` | 文件校验值 |

## 重新运行

在这个文件夹打开终端。下面使用 conda 创建独立环境，随后从随包源码安装锁定版本；首次配置需要网络。

```sh
conda create -y -p ./.r-env -c conda-forge r-base=4.2.3 r-zoo=1.8_12 r-xts
conda activate ./.r-env
R CMD INSTALL vendor/xts_0.13.1.tar.gz
R CMD INSTALL vendor/bidask
Rscript --vanilla run_simulation.R > run.log 2>&1
```

现有 Mac arm64 环境还可以通过 `conda-osx-arm64-explicit.txt` 重建，再执行上面的两条 `R CMD INSTALL`。该清单记录 conda 管理的 xts 0.14.0；本次实际执行前已用源代码安装覆盖为 0.13.1，故覆盖步骤必不可少，入口也会检查实际版本。其他平台优先使用上述按版本创建环境的方法。

模拟会使用较多内存：一次生成 8,190 万个潜在成交观察。运行按场景串行执行并回收内存；不会下载任何 WRDS 数据。

## 验证与解释范围

入口检查核心软件版本、正值与有限 OHLC、价格上下界、每场景 10,000 个有效输出，以及最终 80 行统计/240 项比较。运行前还在稀疏成交样本上核对标量 EDGE 与向量化 EDGE，以及带符号/绝对值两种输出的关系。

匹配到参考表显示精度意味着本次重现了对应模拟结果，不等于估计器无偏，也不证明它在真实市场或所有参数下可靠。标准差反映不同模拟窗口的离散程度；`mean_mcse` 是该场景模拟均值的 Monte Carlo 标准误，两者不要混用。

参考：
- [论文 DOI](https://doi.org/10.1016/j.jfineco.2024.103916)
- [固定版本的作者源码](https://github.com/eguidotti/bidask/tree/2dbafe0087e609c7b153e1a43b7ce6c923daf89c/r)

作者复现包及本包中的衍生运行脚本按随附 GPL-3 LICENSE 使用；作者信息保留在引用和原始源码中。
