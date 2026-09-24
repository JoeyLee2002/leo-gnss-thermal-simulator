# v0.14 发布 QA 报告

日期：2026-09-16  ·  范围：工程热模型交换适配器、映射 GUI 工作流和发布门禁

## 回归门禁

新增 `tests/test_v014_release_regression.m`，覆盖以下 v0.14 入口：

| 区域 | 覆盖 |
|---|---|
| component create | `componentModel('create',spec)` 在无 network 时成功，并保留热容/功率 |
| JSON/MAT 往返 | 导出、再导入均保留 `provenance.inputFingerprint`；报告区分容器与源指纹 |
| scalar uncertainty | 顶层 `uncertainty` 非标量时拒绝 |
| temperature curve grid | 单调 Kelvin 网格插值/网格点评估；重复网格拒绝 |
| mapping preview/apply | preview 只读、冲突为空；apply 需 confirmation token 且写入 provenance |

执行命令：

```matlab
cd('H:\\paper\\leo-gnss-thermal-simulator');
addpath('src');
runtests('tests/test_v014_release_regression.m')
```

结果：**6 passed, 0 failed, 0 incomplete**（MATLAB R2021b）。可重复执行
`tools/verify_v014_release` 生成同一门禁和静态检查结果。

GUI 映射闭环测试：**3 passed, 0 failed, 0 incomplete**；GUI 支持测试：
**9 passed, 0 failed, 0 incomplete**。GUI 冒烟测试完成，7 个页签、3 个主工作区、
121 个结果历元、面片/体网格有限性、10 个图例和中英文界面均通过检查。

## R2021b / checkcode 审查

新增测试文件和发布工具在 R2021b 语法下可解析，未使用更新版本专属语法。
对交换/映射相关新增文件运行 `checkcode(...,'-id')`：

* `tests/test_v014_release_regression.m`、`tools/verify_v014_release.m` 以及
  `componentModel`、I/O 文件、preview/apply、sampleUncertainty、materialLibrary：无告警。
* `src/+leotherm/+model/validateNetworkMapping.m` 的早期单行复合语句和未使用变量
  提示已清理；交换、映射、材料库和 GUI 相关 MATLAB 文件当前 `checkcode` 无告警。

审查结论：未发现单行 `try/catch`、不受支持的 `switch` 语法或依赖隐式名称匹配的
新测试行为。`applyNetworkMapping` 的 `switch` 为 R2021b 支持的标准形式。

## 指纹与验证边界

文档已明确：`report.inputFingerprint` 是当前 JSON/MAT 容器字节摘要，
`report.sourceFingerprint` 是模型声明的上游 `provenance.inputFingerprint`；前者可因
重新格式化/保存而变化，后者用于源数据追溯。二者均不是物理验证、热真空相关、
鉴定裕度或飞行数据验证的证明。

剩余边界：

1. 完整 `run_tests` 在干净 MATLAB 进程中最终通过：**264/264 passed，0 failed，
   0 incomplete**；此前一次设备标定导出阶段的 `0xc0000374` 未能在该测试单独运行
   或最终全量运行中复现，仍建议在 CI 镜像中保留进程级复核。
2. 温度相关材料的 `...Fcn` 仍是 MATLAB-only，不可直接 JSON 交换；跨团队应使用
   带 `temperatureK` 网格的表格。
3. mapping 仍要求显式 network node target，不会自动推断连接、边界或物理参数；
   通过数据契约校验不等于求解结果正确。
