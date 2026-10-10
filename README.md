<div align="center">

# GKI BakaSU SUSFS

基于 GitHub Actions 构建 Android GKI 内核，集成 BakaSU 与 SUSFS。

[![Release](https://img.shields.io/github/v/release/coolzyd9107/GKI_BakaSU_SUSFS?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/releases)
[![构建内核](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions/workflows/main.yml/badge.svg)](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions/workflows/main.yml)
[![Telegram](https://img.shields.io/static/v1?label=Telegram&message=Channel&color=0088cc)](https://t.me/BakaSUKernelBuilds)
[![BakaSU](https://img.shields.io/badge/KernelSU-BakaSU-5AA300?style=flat-square)](https://github.com/Baka-SU/BakaSU)
[![SUSFS](https://img.shields.io/badge/Filesystem-SUSFS-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

</div>

## 项目说明

本仓库提供 Actions 云端构建流程，按 Android GKI KMI 和安全补丁级别生成 AnyKernel3 安装包。常规构建使用 BakaSU 同时可以自行在工作流配置中启用其它可选功能；也可以选择 Clean build，生成不集成 KernelSU、SUSFS 与可选功能补丁的内核。

内核版本与发布修订从 `data/android*/` 下的 JSON 矩阵读取，并由数据同步工作流定期更新。

## 重要通知

近期我们进行了大幅度的重构，这导致了构建步骤和产物激增，从而导致需要极长的时间来完成包含所有内核版本的内核构建工作流，因此我们不会继续定期或在BakaSU有重大更新时运行所有版本的内核构建与发布Release，此举旨在减轻对GitHub Actions公共资源的长时间占用，每位用户按需分叉(fork)此仓库并自行在分叉后的仓库中单独构建与自己所需内核版本完全一致的单个内核，可大幅度降低算力滥用现象，如对您造成不便，敬请谅解，有关如何使用此仓库及其分支仓库的工作流，可查看README.md的相关部分。

## 支持的 KMI

| Android KMI | 内核系列 | `build_target` 选项 |
|---|---|---|
| Android 12 | 5.10 | `android12-5.10` |
| Android 13 | 5.10 | `android13-5.10` |
| Android 13 | 5.15 | `android13-5.15` |
| Android 14 | 5.15 | `android14-5.15` |
| Android 14 | 6.1 | `android14-6.1` |
| Android 15 | 6.6 | `android15-6.6` |
| Android 16 | 6.12 | `android16-6.12` |
| Android 17 | 6.18 | `android17-6.18` |

5.10 和 5.15 都对应多个 Android KMI。尤其 5.15 的 Android 13 与 Android 14 存在相同的内核版本号，不能仅凭 `5.15.xxx` 自动判断 KMI；指定版本构建时必须手动选择对应的 Android 版本。Android 17 / 6.18 当前已支持基础构建，部分附属组件按上游支持状态自动跳过。

## 运行构建

1. 打开仓库的 [Actions](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions) 页面，选择 **构建内核** 工作流并点击 **Run workflow**。
2. 在 `build_target` 中选择一个 KMI，或选择 `all` 构建全部目标。choice 是单选项；需要构建多个但不是全部时，分别运行对应目标。
3. 根据需要设置功能选项和 `release_type`，然后启动工作流。
4. 构建完成后，在运行详情页的 **Artifacts** 下载产物；创建 Release 时也可以从 Release 页面下载。

### 按内核版本筛选

启用 `build_kernel_version` 后，版本筛选优先于普通版本开关。`kernel_version_filter` 接受完整版本或系列通配符：

| 输入 | 作用 |
|---|---|
| `6.6.66` | 从对应 KMI 的版本数据中构建 `6.6.66` |
| `6.6.X` 或 `6.6.x` | 构建该 KMI 数据中所有 6.6 子版本 |

选择规则：

- 5.10：`kernel_android_version` 必须选 `android12` 或 `android13`。
- 5.15：必须选 `android13` 或 `android14`。
- 6.1、6.6、6.12、6.18：工作流分别使用 Android 14、15、16、17 的 KMI，无需手动选择。

补丁级别、发布 revision 和 LTS 版本由对应 JSON 数据读取。指定版本构建不会创建 GitHub Release，即使 `release_type` 选择了预发布或正式发布。

### 发布类型

普通版本构建的 `release_type` 有以下选项：

- `Actions`：仅保留 Actions 运行产物，不创建 Release。默认值。
- `Pre-Release`：在本仓库构建成功后创建预发布。
- `Release`：在本仓库构建成功后创建正式发布。

Fork 仓库只生成 Actions 产物，不会向上游仓库发布 Release。

## BakaSU 分支

`kernelsu_branch` 留空时使用 `main`。也可以填写 BakaSU 的远程分支名，或完整的 40 位 commit SHA。工作流会在构建开始时解析并固定该分支对应的提交，因此同一次运行的各个 KMI 使用相同代码；发布说明会链接到实际构建的 BakaSU 提交。

## 可选构建功能

| 选项 | 说明 |
|---|---|
| `clean_build` | 不集成 BakaSU、SUSFS 及可选功能补丁。 |
| `cancel_susfs` | 关闭 SUSFS 集成。默认启用 SUSFS；Android 17 / 6.18 暂无上游分支，会自动跳过。 |
| `use_zram` | 启用 ZRAM 增强（LZ4KD）。Android 17 / 6.18 暂无对应补丁，会自动跳过。 |
| `use_bbg` | 启用 BBG 防格机补丁。 |
| `use_rekernel` | 启用 Re-Kernel 驱动，功能仍在测试。Android 17 / 6.18 暂时跳过，待本仓库适配上游新源码布局。 |
| `cve_2026_43499_patch` | 应用 CVE-2026-43499 修复链，默认开启；6.18 暂无本仓库适配补丁，会自动跳过。 |
| `build_bypass` | 额外构建 Bypass Image，与普通 Image 一起放入安装包。 |
| `droidspaces` | 选择 Droidspaces 容器补丁：`off`、`678`、`123` 或 `345`。6.12 及以上使用上游的通用补丁。 |
| `droidspaces_ntsync` | 在支持的组合中启用 NTSync，需同时启用 Droidspaces。当前没有 Android 17 / 6.18 补丁，该组合会自动跳过。 |

Bypass 模式用于排查内核模块版本兼容问题，不用于绕过 root 检测。启用后会进行第二次完整编译，并增加构建时间。刷入时按安装脚本提示选择普通 Image 或 Bypass Image。

Droidspaces 补丁具有实验性，不同设备和内核版本可能需要尝试不同槽位。Android 16 / 6.12 和 Android 17 / 6.18 只有一种槽位补丁，选任一非 `off` 值即可。上游没有 Android 14 / 5.15 的 NTSync 兼容补丁；该组合会使构建失败，请保持关闭。Android 17 / 6.18 的 NTSync 补丁缺失时会自动跳过。

## 构建产物

产物名称包含 Android KMI、完整内核版本和 OS 安全补丁级别；存在上游 revision 时还会带上 revision。例如：

```text
android14-5.15.148-2024-05-r25-BakaSU-AnyKernel3.zip
```

启用 Bypass 后，安装包中同时包含普通 `Image` 和 `Bypass-Image`。选择与设备 Android KMI、内核分支相符的产物；刷入前备份原厂 Boot 镜像，并确保设备有可用的恢复方式。

## Stock Config

若仓库中存在 `config/stock_defconfig`，构建会自动将其用于 `/proc/config.gz` 配置伪装；文件不存在时跳过此步骤。可以从设备当前官方内核取得 `/proc/config.gz`，解压后放入该目录并命名为 `stock_defconfig`。

## GKI 数据同步

[更新 GKI 版本数据](.github/workflows/update-gki-data.yml)工作流每周一 UTC 08:00 自动运行，也可以手动触发。工作流会运行同步测试、更新 JSON、验证构建矩阵，并提交数据变更。

## 致谢

- [zzh20188](https://github.com/zzh20188)：曾经的上游 GKI 构建仓库作者，目前此仓库已脱离分支网络，zzh20188/GKI_KernelSU_SUSFS 将不再是此仓库的上游仓库
- [coolzyd9107](https://github.com/coolzyd9107)：本仓库维护者。
- [zhuzhuzihan](https://github.com/zhuzhuzihan)：工作流修复及 Telegram Bot 开发与维护。
- [TanakaLun](https://github.com/TanakaLun)：工作流修复与功能改进。
- [YC酱luyancib](https://github.com/luyanci)：Telegram Bot 与构建流程建议。
- [AlexLiuDev233](https://github.com/AlexLiuDev233)：工作流问题修复。
- [cctv18](https://github.com/cctv18)：工作流、6.12 支持及 SUSFS 问题修复建议。

新构建和重要变更通知见 [Telegram 频道](https://t.me/BakaSUKernelBuilds)；BakaSU 官方频道见 [BakaSU_Grp](https://t.me/BakaSU_Grp)。
