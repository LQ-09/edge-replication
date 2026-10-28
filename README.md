# EDGE Spread Estimation — Replication and Empirical Validation

A reproducible R/Python study of the EDGE bid–ask spread estimator in Ardia, Guidotti & Kroencke (2024).

## Start here

- **Simulation:** reproduces Table 2A/2B with pinned author code, fixed seeds, and saved comparison outputs.
- **Validation:** the stored results report 240/240 matches to the author reference tables and 160/160 mean/standard-deviation matches to the published table at displayed precision.
- **Empirical study:** five stocks in the first half of 2024, with 30 matched stock-months. The recorded correlation is 0.0304 and RMSE is 37.983 bps; this weak result is retained.
- **Intraday extension:** 44 of 45 candidate intervals passed the documented quality gates.

These figures describe repository evidence and were not recomputed during this README review.

## Reproduce

Use R 4.2.3 with the root `renv.lock` to restore the simulation environment, then run `Rscript run_simulation.R`. The script checks key package versions and includes estimator self-checks.

For the Python pipeline and tests:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-lock.txt
python -m unittest discover -s tests -v
```

Simulation can run from the public repository. Empirical reproduction requires authorized WRDS inputs; raw licensed data and individual empirical outputs must remain private.

See [report](REPORT.md), [results](RESULTS.md), [methodology](docs/methodology.md), and [empirical reproduction](docs/reproduce_empirical.md). Retain the existing detailed Chinese README below this introduction.

---

# EDGE 项目：模拟复现、真实数据验证与日内扩展

模拟复现：2026-10-14；真实数据分析：2026-10-15。对象为 Ardia, Guidotti & Kroencke (2024), *Efficient Estimation of Bid-Ask Spreads from Open, High, Low, and Close Prices*, Journal of Financial Economics 161, 103916。

## 当前完成情况

- **模拟**：Table 2A/2B 全部运行；240 项作者参考表核对通过，正式出版表另核对 160 项均值/标准差，全部达到原表展示精度。
- **真实月度实证**：5 只股票、2024 年上半年、620 个股票日、30 个匹配股票月。相关系数 0.0304，RMSE 37.983 bps；结果偏弱，如实保留。
- **日内扩展**：15 个交易日、45 个候选时段，44 个通过质量门槛。一个苹果午间对照时段因报价匹配率低于 90% 被排除。
- **交付文件**：[PDF 报告](docs/EDGE_Project_Report.pdf)、[12 页演示稿](docs/EDGE_Midterm_Presentation.pptx)、[约 20 分钟讲稿](docs/presentation_notes.md)。录制与 Canvas 提交仍需本人完成。
- **报告与复现说明**：[最终报告](REPORT.md)、[方法与局限](docs/methodology.md)、[数据字典](docs/data_dictionary.md)、[真实数据复跑步骤](docs/reproduce_empirical.md)。

公开仓库不含 WRDS 授权原始数据或逐笔/个股实证输出。**克隆并安装依赖后可重跑模拟；重跑真实实证还需要有权限的 WRDS 数据。**本项目没有使用作者随机占位 CSV 冒充真实数据。

Python 部分使用 3.12，直接依赖见 `requirements.txt`，完整锁定版本见 `requirements-lock.txt`。执行：

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-lock.txt
python -m unittest discover -s tests -v
```

## 运行入口与依赖

本仓库有两个独立的 R 项目，**在所选项目的目录运行 `renv::restore()`**。`renv` 是 R 包环境管理工具；`library(...)` 加载安装后的 R 包，并不寻找同名本地 `.R` 文件。

| 目的 | 工作目录 | 入口 | 依赖配置 |
|---|---|---|---|
| 重现已验证的 Table 2A/2B | 仓库根目录 | `run_simulation.R` | 根 `renv.lock`，5 个包（含 renv 和间接依赖 lattice） |
| 检查或运行作者完整原始项目 | `reference/original/` | `main.R` | 作者 `renv.lock`，75 个包 |

完整作者项目包含原包目录、16 个分析脚本、renv 启动文件及随机占位输入。`main.R` 会同时运行模拟和基于输入文件的分析；占位数据的输出不能称为真实市场实证。

## 本次范围

执行作者 Table 2 的完整两组模拟：频繁交易（A）与稀疏交易（B），每组包含 0.5%、1%、3%、5%、8% 五种真实价差，使用 EDGE、OHLC、CHLO、OHL、CHL、AR、CS、ROLL 八种方法。每个场景模拟 10,000 个连续的 21 日窗口，合计 100,000 个窗口、800,000 个估计值。

对照来源是用户提供的 `dataverse_files.zip` 内作者保存的 `output/tab_2A.tex` 和 `output/tab_2B.tex`，已原样保存在 `reference/`。另已核对正式出版 PDF 第 8 页 Table 2 的 160 项均值/标准差，全部一致；零值比例只出现在作者附表。

压缩包 README 明确指出 `input/stocks.csv` 和 `input/cryptos.csv` 是随机生成的占位数据。本次模拟不需要、也未读取这些文件。真实实证和财报邻近日内扩展已使用另行下载的 WRDS 数据完成，见 REPORT.md。

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
| `results/sessionInfo.txt`、`results/package_versions.csv` | 实际计算环境 |
| `run.log` | 本次运行日志 |
| `reference/original/` | 完整作者原包，含 main.R、全部 scripts、renv 配置和随机占位输入 |
| `reference/tab_2A.tex`、`tab_2B.tex` | 模拟验证使用的作者参考表 |
| `.Rprofile`、`renv/`、`renv.lock` | Table 2 入口的自动加载与依赖恢复配置 |
| `SHA256SUMS.txt` | 文件校验值 |

## 重新运行

先安装 Git、Conda/Miniforge，然后执行下面的命令。已有 R 4.2.3 和编译工具时，可省略创建/激活 Conda 环境两行。

```sh
git clone https://github.com/LQ-09/edge-replication.git
cd edge-replication
conda create -y -p ./.r-env -c conda-forge r-base=4.2.3
conda activate ./.r-env
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript run_simulation.R --check-only
Rscript run_simulation.R > run.log 2>&1
```

`.Rprofile` 从随仓库提供的 `renv/activate.R` 启动 renv 1.0.0；首次恢复需要网络，自动安装锁定版本的 lattice、zoo、xts 与作者 GitHub 提交对应的 bidask。编译源码包需要编译器；上述 Conda 的 R 环境提供相应工具链。不要在这条流程中添加 `--vanilla`，否则会跳过项目环境的自动加载。

`--check-only` 验证版本及小样本计算，不重跑完整模拟，也不改动已保存结果。完整运行会更新 `results/` 和运行日志。`vendor/` 保存源码供追溯，通常无需手动安装。`conda-osx-arm64-explicit.txt` 是首次运行的历史环境记录，不是当前推荐的恢复入口。

作者完整入口的独立恢复方法见 [reference/README.md](reference/README.md)。本次修复原因、验证范围和工具链说明见 [依赖检查记录](docs/dependencies.md)。依赖恢复不包含下载授权市场数据。

模拟会使用较多内存：一次生成 8,190 万个潜在成交观察。运行按场景串行执行并回收内存；不会下载任何 WRDS 数据。

## 验证与解释范围

入口检查核心软件版本、正值与有限 OHLC、价格上下界、每场景 10,000 个有效输出，以及最终 80 行统计/240 项比较。运行前还在稀疏成交样本上核对标量 EDGE 与向量化 EDGE，以及带符号/绝对值两种输出的关系。

匹配到参考表显示精度意味着本次重现了对应模拟结果，不等于估计器无偏，也不证明它在真实市场或所有参数下可靠。标准差反映不同模拟窗口的离散程度；`mean_mcse` 是该场景模拟均值的 Monte Carlo 标准误，两者不要混用。

参考：
- [论文 DOI](https://doi.org/10.1016/j.jfineco.2024.103916)
- [固定版本的作者源码](https://github.com/eguidotti/bidask/tree/2dbafe0087e609c7b153e1a43b7ce6c923daf89c/r)

作者复现包及本包中的衍生运行脚本按随附 GPL-3 LICENSE 使用；作者信息保留在引用和原始源码中。
