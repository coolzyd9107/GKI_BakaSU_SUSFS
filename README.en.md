[简体中文](README.md) | [**English**](README.en.md) | [Bahasa Indonesia](README.id.md)

# GKI BakaSU SUSFS · Cogan Fork

> An independent fork of **[coolzyd9107's original project](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS)**, maintained by **[Cogan](https://github.com/cogan17)**. This is **not** the official upstream repository.

[![Release](https://img.shields.io/github/v/release/cogan17/GKI_BakaSU_SUSFS?include_prereleases&label=Release)](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases)
[![Custom Build](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml/badge.svg)](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml)
[![License](https://img.shields.io/github/license/cogan17/GKI_BakaSU_SUSFS)](LICENSE)

**Quick links:** [Actions](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions) · [Custom Build](.github/workflows/kernel-custom.yml) · [Main Build](.github/workflows/main.yml) · [Manual Release](.github/workflows/manual-release.yml) · [Releases](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases)

## Project Description

This fork builds Android GKI kernels through GitHub Actions with **BakaSU + SUSFS** and configurable integrations such as NoMount, ZRAM, BBG, and Re-Kernel. Successful builds provide **AnyKernel3 ZIP** packages. Choose `clean_build` to exclude BakaSU, SUSFS, and optional patches.

**GKI/KMI is not the installed Android OS version.** For example, an Android 16 device can use Android 14 GKI / Linux 6.1 if its actual kernel interface is compatible. Verify the device's KMI, stock kernel, and compatibility before flashing; matching Android OS versions alone is insufficient.

## Important Notice

This is an **independently maintained Cogan fork**. The original project and Chinese-language documentation are from [coolzyd9107/GKI_BakaSU_SUSFS](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS). Cogan adds version-display, build workflow, packaging, and documentation improvements. Fork release notes are **not** official upstream announcements.

**Support limitations:** Android 17 / 6.18 has limited feature support; unsupported upstream patch sets are skipped. Kernel series 5.10 and 5.15 each cover multiple Android KMIs, so choose the correct KMI explicitly.

## Supported KMI

| Android KMI | Kernel Series | `build_target` Option |
|---|---|---|
| Android 12 | 5.10 | `android12-5.10` |
| Android 13 | 5.10 | `android13-5.10` |
| Android 13 | 5.15 | `android13-5.15` |
| Android 14 | 5.15 | `android14-5.15` |
| Android 14 | 6.1 | `android14-6.1` |
| Android 15 | 6.6 | `android15-6.6` |
| Android 16 | 6.12 | `android16-6.12` |
| Android 17 | 6.18 | `android17-6.18` |

Both 5.10 and 5.15 correspond to multiple Android KMI. Especially for Android 13 and Android 14 which share the same kernel version for 5.15, KMI cannot be automatically determined solely by `5.15.xxx`; you must manually select the corresponding Android version when building a specified version. Android 17 / 6.18 currently supports basic builds, with some auxiliary components automatically skipped based on upstream support status.

## Running Builds

### 1. Android Kernel Build - Custom (recommended)

1. Open **[Custom Build](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml)**, choose `main`, then **Run workflow**.
2. Set `android_version`, `kernel_version`, `sub_level`, `os_patch_level` (e.g. `lts`), and `revision`.
3. Optionally set `version` (e.g. `Cogan`), `kernelsu_branch` (blank selects BakaSU's default branch), and `build_time` (`N` or blank uses the current UTC time).
4. Select appropriate features, run the build, and download `*-AnyKernel3.zip` from the successful run's **Artifacts**.

**Cogan r7 example:** `android14` / `6.1` / `177` / `lts` / `r7` with custom label `Cogan`. This is not a universal flashing configuration.

### 2. Build Kernel (matrix / version filter)

In **[Build Kernel](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/main.yml)**, set `build_target` to one KMI or `all`. Alternatively enable `build_kernel_version` and enter `6.6.66` or a series wildcard such as `6.6.X`. For 5.10 / 5.15, also specify `kernel_android_version`.

**Note:** The main workflow still has an outdated `build_time` default. Enter `N` if you want the current UTC time. Custom Build already defaults to `N`.

### 3. Manual Release From Run

Use **[Manual Release From Run](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/manual-release.yml)** to publish the original AnyKernel3 ZIP from a successful run:

1. Open the workflow on `main`.
2. Enter the numeric `source_run_id` and choose `Pre-Release` or `Release`.
3. It verifies the source run, ZIP integrity, and required files, then attaches the original ZIP to GitHub Releases without repacking.

**Important:** The main workflow's automatic release job is currently restricted to a different repository; use Manual Release for this fork. Example: r7 [Run 38020806221](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/runs/38020806221) → [Cogan r7 Release](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases/tag/BakaSU-run-38020806221).

## BakaSU Branch

When `kernelsu_branch` is left blank, `main` is used. You can also enter a BakaSU remote branch name, or a full 40-character commit SHA. The workflow will resolve and lock in the commit corresponding to that branch at the start of the build, so each KMI in the same run uses the same code; release notes will link to the actually built BakaSU commit.

## Optional Build Features

| Option | Description |
|---|---|
| `clean_build` | Do not integrate BakaSU, SUSFS, and optional feature patches. |
| `cancel_susfs` | Disable SUSFS integration. SUSFS is enabled by default; Android 17 / 6.18 has no upstream branch yet and will be skipped automatically. |
| `use_zram` | Enable ZRAM enhancements (LZ4KD). Android 17 / 6.18 has no corresponding patch yet and will be skipped automatically. |
| `use_bbg` | Enable BBG anti-brick/anti-reboot patches. |
| `use_rekernel` | Enable Re-Kernel driver, features are still testing. Temporarily skipped on Android 17 / 6.18 until this repository adapts to upstream's new source layout. |
| `cve_2026_43499_patch` | Apply CVE-2026-43499 fix chain, enabled by default; 6.18 has no adaptation patch in this repository yet and will be skipped automatically. |
| `build_bypass` | Additionally build a Bypass Image, included in the installation package alongside the regular Image. |
| `droidspaces` | Select Droidspaces container patch: `off`, `678`, `123`, or `345`. 6.12 and above use upstream generic patches. |
| `droidspaces_ntsync` | Enable NTSync in supported combinations, requires Droidspaces to be enabled simultaneously. Currently no Android 17 / 6.18 patch available, this combination will be skipped automatically. |
| `use_nomount` | NoMount integration. **Current limitation:** the reusable build workflow runs the NoMount installation step on non-clean builds even when this toggle is `false`. Do not rely on the toggle to disable NoMount until the workflow is fixed. |

**Version display:** For Android 14 GKI / Linux 6.1 with a custom label, Cogan shortens compiler metadata shown in HyperOS Settings while preserving the parser-compatible version structure. Automatic UTC build time uses `YYYY-MM-DD HH:mm:ss UTC`. Display behavior can vary by device.


Bypass mode is used to troubleshoot kernel module version compatibility issues, not to bypass root detection. When enabled, a second full compilation is performed, increasing build time. Follow the installation script prompt to choose between regular Image or Bypass Image when flashing.

Droidspaces patches are experimental, different devices and kernel versions may require trying different slots. Android 16 / 6.12 and Android 17 / 6.18 only have one slot patch type, select any non-`off` value. Upstream lacks NTSync compatibility patches for Android 14 / 5.15; this combination will cause the build to fail, please keep it disabled. Android 17 / 6.18 will automatically skip if the NTSync patch is missing.

## Build Artifacts

Successful Custom Builds provide directly flashable `*-AnyKernel3.zip` files. Current build artifacts do not require a second ZIP extraction or manual repacking. Enabling `build_bypass` may additionally include `Bypass-Image`.

### Cogan r7: verified example

- **Kernel:** `6.1.177-android14-11-Cogan` (Android 14 GKI / 6.1.177 LTS).
- **Test device:** Xiaomi 14T Pro (`2407FPN8EG`), Android 16 / HyperOS.
- **Verified:** successful GitHub Actions compilation and ZIP packaging; correct kernel version shown by HyperOS (no `Unavailable`); BakaSU and built-in NoMount detected by their managers.
- **Not verified:** exhaustive operation of every optional patch or compatibility across other devices and ROMs.

**Before flashing:** verify the exact KMI, back up the original boot partition and any others your installation may modify, and prepare a reliable recovery method. Use a compatible kernel flasher. Flash at your own risk.

## Stock Config

If `config/stock_defconfig` exists in the repository, the build will automatically use it for `/proc/config.gz` config masking; if the file does not exist, this step is skipped. You can extract `/proc/config.gz` from the device's current official kernel, decompress it, place it in this directory, and name it `stock_defconfig`.

## GKI Data Synchronization

The [Update GKI Version Data](.github/workflows/update-gki-data.yml) workflow runs automatically every Monday at UTC 08:00, and can also be triggered manually. The workflow runs sync tests, updates JSON, validates the build matrix, and commits data changes.

## Acknowledgments

- **Original project and primary developer:** [coolzyd9107 / GKI_BakaSU_SUSFS](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS).
- **Cogan fork, maintenance and customization:** [Cogan (cogan17)](https://github.com/cogan17).
- **Project history and contributors:** [zzh20188](https://github.com/zzh20188), [zhuzhuzihan](https://github.com/zhuzhuzihan), [TanakaLun](https://github.com/TanakaLun), [luyancib](https://github.com/luyancib), [AlexLiuDev233](https://github.com/AlexLiuDev233), and [cctv18](https://github.com/cctv18).
- Thanks to the developers and contributors of **BakaSU, KernelSU, SUSFS, NoMount, Re-Kernel, AnyKernel3**, and Android GKI.

This repository is licensed under **GPL-2.0**. The [upstream Telegram channel](https://t.me/BakaSUKernelBuilds) is an upstream community resource, not a dedicated Cogan support channel.
