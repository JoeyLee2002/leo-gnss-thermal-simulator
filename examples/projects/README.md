# 示例项目

这些 MAT 文件可以通过 GUI 的“打开项目”直接载入。它们用于熟悉软件流程，不代表具体卫星标定结果。

- `01_first_simulation.mat`：第一次使用：600 km 对地定向、2 小时快速仿真。
- `02_thermal_lag_24h.mat`：热滞后分析：24 小时周期热状态收敛。
- `03_physical_sweep.mat`：参数扫描：日期、倾角、RAAN 和轨道高度物理扫描。
- `04_telemetry_validation.mat`：遥测验证：内置合成输入，仅用于熟悉导入、映射和预检流程。
- `05_3d_geometry.mat`：三维输入：STL/OBJ 面片和 Gmsh 四面体体网格。两条求解链彼此独立。
- `06_surface_volume_coupled.mat`：完整耦合：严格共同边界面、守恒外部热流、体内导热、显式接触和固定温度边界。
