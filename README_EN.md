<div align="center">

# GKI BakaSU SUSFS

Build Android GKI kernels with BakaSU and SUSFS through GitHub Actions.

[简体中文](README.md) / English

[![Release](https://img.shields.io/github/v/release/coolzyd9107/GKI_BakaSU_SUSFS?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/releases)
[![Build Kernel](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions/workflows/main.yml/badge.svg)](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions/workflows/main.yml)
[![Telegram](https://img.shields.io/static/v1?label=Telegram&message=Channel&color=0088cc)](https://t.me/BakaSUKernelBuilds)
[![BakaSU](https://img.shields.io/badge/KernelSU-BakaSU-5AA300?style=flat-square)](https://github.com/Baka-SU/BakaSU)
[![SUSFS](https://img.shields.io/badge/Filesystem-SUSFS-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

</div>

## Overview

This repository provides GitHub Actions workflows that generate AnyKernel3 installation packages for Android GKI kernel module interfaces (KMIs) and security patch levels. Regular builds use BakaSU and can include other optional features configured in the workflow. You can also select a clean build to produce a kernel without KernelSU, SUSFS, or optional feature patches.

Kernel versions and release revisions are read from the JSON matrices under `data/android*/` and updated periodically by the data synchronization workflow.

## Important Notice

Recent major refactoring significantly increased the number of build steps and artifacts, making a workflow that includes every kernel version take an excessively long time. We will therefore no longer regularly run and publish builds for all versions, including after major BakaSU updates. This change reduces prolonged use of shared GitHub Actions resources.

Users should fork this repository and build only the kernel version they need in their fork. Building a single matching kernel greatly reduces unnecessary compute usage. We apologize for any inconvenience. See the relevant sections below for instructions on using the workflows in this repository and its forks.

## Supported KMIs

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

Both 5.10 and 5.15 correspond to multiple Android KMIs. In particular, Android 13 and Android 14 on 5.15 can have identical kernel version numbers, so the KMI cannot be determined from `5.15.xxx` alone. You must select the corresponding Android version when building a specific version. Android 17 / 6.18 currently supports basic builds; some auxiliary components are skipped automatically according to upstream support.

## Running Builds

1. Open the repository's [Actions](https://github.com/zhuzhuzihan/GKI_BakaSU_SUSFS/actions) page, select the **Build Kernel** workflow, and click **Run workflow**.
2. Select a KMI under `build_target`, or select `all` to build every target. This is a single-choice field; to build several targets without building all of them, run the workflow separately for each target.
3. Configure the feature options and `release_type` as needed, then start the workflow.
4. When the build finishes, download its output from **Artifacts** on the run summary page. If a release was created, you can also download it from the Releases page.

### Filter by Kernel Version

When `build_kernel_version` is enabled, version filtering takes precedence over the regular version options. `kernel_version_filter` accepts a full version or a series wildcard:

| Input | Effect |
|---|---|
| `6.6.66` | Build `6.6.66` from the selected KMI's version data |
| `6.6.X` or `6.6.x` | Build every 6.6 patch version in the selected KMI's data |

Selection rules:

- 5.10: `kernel_android_version` must be `android12` or `android13`.
- 5.15: `kernel_android_version` must be `android13` or `android14`.
- 6.1, 6.6, 6.12, and 6.18: the workflow uses the Android 14, 15, 16, and 17 KMIs respectively, with no manual selection required.

Patch levels, release revisions, and LTS versions are read from the corresponding JSON data. A specific-version build does not create a GitHub Release, even when `release_type` is set to `Pre-Release` or `Release`.

### Release Types

The following `release_type` options are available for regular version builds:

- `Actions`: Keep only the workflow artifacts and do not create a Release. This is the default.
- `Pre-Release`: Create a pre-release after a successful build in this repository.
- `Release`: Create a full release after a successful build in this repository.

Forks only produce workflow artifacts and never publish a Release to the upstream repository.

## BakaSU Branch

When `kernelsu_branch` is empty, the workflow uses `main`. You can also enter a remote BakaSU branch name or a full 40-character commit SHA. At the start of a build, the workflow resolves and pins the branch to a commit so every KMI in that run uses the same code. Release notes link to the exact BakaSU commit used for the build.

## Optional Build Features

| Option | Description |
|---|---|
| `clean_build` | Build without BakaSU, SUSFS, or optional feature patches. |
| `cancel_susfs` | Disable SUSFS integration. SUSFS is enabled by default; it is skipped automatically on Android 17 / 6.18 because no upstream branch is available. |
| `use_zram` | Enable ZRAM enhancements (LZ4KD). This is skipped automatically on Android 17 / 6.18 because no corresponding patch is available. |
| `use_bbg` | Enable the BBG anti-brick patch. |
| `use_rekernel` | Enable the experimental Re-Kernel driver. This is temporarily skipped on Android 17 / 6.18 until this repository supports the new upstream source layout. |
| `cve_2026_43499_patch` | Apply the CVE-2026-43499 fix chain. This is enabled by default; 6.18 is skipped because this repository does not yet have an adapted patch. |
| `build_bypass` | Build an additional Bypass Image and include it alongside the standard Image in the installation package. |
| `droidspaces` | Select a Droidspaces container patch: `off`, `678`, `123`, or `345`. Kernel 6.12 and later use the universal upstream patch. |
| `droidspaces_ntsync` | Enable NTSync for supported combinations. Droidspaces must also be enabled. Android 17 / 6.18 is skipped automatically because no patch is currently available. |
| `use_nomount` | Add kernel support for the [NoMount](https://github.com/maxsteeel/nomount) mount meta-module. The companion NoMount module must also be installed. This is skipped for clean builds. |

Bypass mode is intended for diagnosing kernel module version compatibility issues, not for bypassing root detection. Enabling it performs a second full compilation and increases the build time. During installation, follow the installer's prompt to select either the standard Image or the Bypass Image.

Droidspaces patches are experimental. Different devices and kernel versions may require different patch slots. Android 16 / 6.12 and Android 17 / 6.18 have only one patch slot, so any value other than `off` works. Upstream does not provide an NTSync compatibility patch for Android 14 / 5.15; enabling that combination causes the build to fail, so leave NTSync disabled. If the Android 17 / 6.18 NTSync patch is unavailable, it is skipped automatically.

## Build Artifacts

Artifact names include the Android KMI, full kernel version, and OS security patch level. An upstream revision is also included when available. For example:

```text
android14-5.15.148-2024-05-r25-BakaSU-AnyKernel3.zip
```

When Bypass is enabled, the installation package contains both the standard `Image` and `Bypass-Image`. Select an artifact that matches your device's Android KMI and kernel branch. Before flashing, back up the stock boot image and make sure you have a working device recovery method.

## Stock Config

If `config/stock_defconfig` exists in the repository, the build automatically uses it to spoof the `/proc/config.gz` configuration. This step is skipped when the file does not exist. You can obtain `/proc/config.gz` from the device's current stock kernel, decompress it, place it in this directory, and name it `stock_defconfig`.

## GKI Data Synchronization

The [Update GKI Version Data](.github/workflows/update-gki-data.yml) workflow runs automatically every Monday at 08:00 UTC and can also be triggered manually. It runs synchronization tests, updates the JSON files, validates the build matrix, and commits the data changes.

## Acknowledgements

- [zzh20188](https://github.com/zzh20188): Author of the former upstream GKI build repository. This repository is no longer part of that fork network, and `zzh20188/GKI_KernelSU_SUSFS` is no longer its upstream repository.
- [coolzyd9107](https://github.com/coolzyd9107): Maintainer of this repository.
- [zhuzhuzihan](https://github.com/zhuzhuzihan): Workflow fixes and Telegram bot development and maintenance.
- [TanakaLun](https://github.com/TanakaLun): Workflow fixes and feature improvements.
- [YC酱luyancib](https://github.com/luyanci): Telegram bot and build workflow suggestions.
- [AlexLiuDev233](https://github.com/AlexLiuDev233): Workflow fixes.
- [cctv18](https://github.com/cctv18): Workflow, kernel 6.12 support, and SUSFS troubleshooting suggestions.

See the [Telegram channel](https://t.me/BakaSUKernelBuilds) for new builds and important updates. The official BakaSU channel is [BakaSU_Grp](https://t.me/BakaSU_Grp).
