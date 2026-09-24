# GRACE-FO真实遥测接入案例

## 已取得的数据

NASA/JPL发布的GRACE-FO RL04一级数据，GFZ提供公开下载。固定选择2024-01-01和
2024-01-02，含C、D两颗卫星。不是根据仿真效果选择日期。

- [2024-01-01原始数据包](https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/2024/gracefo_1B_2024-01-01_RL04.ascii.noLRI.tgz)
- [2024-01-02原始数据包](https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/2024/gracefo_1B_2024-01-02_RL04.ascii.noLRI.tgz)
- [一级数据手册，2019-09-11](https://isdc-data.gfz.de/grace-fo/DOCUMENTS/Level-1/GRACE-FO_L1_Data_Product_User_Handbook_20190911.pdf)
- [数据集DOI](https://doi.org/10.5067/GFJPL-L1B04)
- [IERS闰秒表](https://hpiers.obspm.fr/iers/bul/bulc/Leap_Second.dat)

本机原始数据位于 `results/flight_telemetry/raw`，完整数据包各约136 MB。
已解出两天C、D的IHK1B仪器遥测、GNI1B惯性轨道和SCA1B姿态，另有第一天C的
GNV1B。13个已解压科学数据文本的MD5均与提供方包内checksum一致。
手册及原始产品头保留了来源、单位、时间约定和数据政策。软件MIT许可不覆盖这些数据。

## 复现

已有下载数据时：

```matlab
startup
addpath(fullfile(pwd,'studies','telemetry'))
summary = run_gracefo_telemetry_audit;
```

默认输出到新的带时间戳目录，不覆盖旧报告。也可显式给出原始目录和新的空输出目录。

在另一台机器上下载，可使用MATLAB内置函数，无需Python：

```matlab
rawDirectory = fullfile(pwd,'results','flight_telemetry','raw');
if ~isfolder(rawDirectory), mkdir(rawDirectory); end
base = 'https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/2024/';
for date = {'2024-01-01','2024-01-02'}
    name = ['gracefo_1B_' date{1} '_RL04.ascii.noLRI.tgz'];
    archive = fullfile(rawDirectory,name);
    if ~isfile(archive)
        websave(archive,[base name],weboptions('Timeout',120));
    end
    % untar解出全部产品，需要比压缩包更大的磁盘空间。
    untar(archive,rawDirectory);
end
run_gracefo_telemetry_audit(rawDirectory);
```

原始包内的checksum文件为MD5清单，应按日期分别保存并检查所用文件。
脚本另对IHK输入生成SHA-256，用于固定本次分析来源，但自算哈希不替代提供方校验。

## 已运行结果

2026-09-03运行的软件版本为0.4.0，输出位于
`results/flight_telemetry/audit_20260903_073741`：

| 项目 | 结果 |
|---|---:|
| 卫星日 | 4 |
| 温度通道编号 | 17 |
| 温度通道日 | 68 |
| 原始测温记录 | 48,960 |
| 通过当前质量检查的记录 | 48,960 |
| 被拒绝测温记录 | 0 |
| 与整秒轨道精确重合的测温记录 | 0 |

每个通道每天720个样本，采样间隔约120秒。全零质量标记只表示通过本次筛选，
不代表传感器无误差或热模型已得到证实。原始测温图显示实际温度变化，但尚未将
变化归因于某一热源或证明其热滞后时间常数。

输出包括逐通道CSV、全量质量总表、68行汇总表、MAT归档、中英文原始测温图和
中文检查报告。没有插值、补齐、四舍五入配对或按效果挑选数据。

## 正式验证还缺什么

1. **传感器安装位置。** IHK1B给出05、06等编号，当前资料未确认其与天线、射频
   前端、振荡器等组件的关系。导出列保留 `sensor_05_degC` 这类源含义，不自动映射。
2. **任务热网络及功率分配。** 默认11节点网络不是GRACE-FO任务模型。电压不是
   节点功耗，不能拿电压乘一个猜测常数驱动热网络。
3. **同历元驱动。** 温度有微秒时间标签，轨道是整秒。严格不插值时，应在实测
   时刻通过独立动力学传播求状态或取得相应产品，再提供同一惯性系太阳与姿态。
4. **留出验证。** 第一日可用于必要标定，第二日预留评估；当前没有执行该标定，
   更没有把训练误差当作验证误差。跨季节推广仍需更多独立工况。

因此，当前完成的是**真实数据接入和可用性检查**，不是**真实卫星热模型验证通过**。

## 导入图形界面

逐传感器CSV可在“遥测与验证”页导入。时间和质量列会自动识别，测温列保持未映射。
获得可靠节点位置说明后，在映射表中选“温度”、对应热节点和“摄氏度”。
不能为了让按钮跑通而随便指定一个默认节点。没有完整驱动时，导入成功不意味着
可以执行轨道或热功率驱动；也不应期待与不同时刻的默认单场景产生有效配对。

解析接口为 `leotherm.readGracefoIhk`，严格支持RL04 ASCII IHK1B、2018年至2026年。
不支持接收机时间冒充GPS时间、不支持跨支持区间猜测闰秒，重复同一传感器历元报错。
不同传感器在同一时刻观测属于合法记录。
