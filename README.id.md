[简体中文](README.md) | [English](README.en.md) | [**Bahasa Indonesia**](README.id.md)

# GKI BakaSU SUSFS · Fork Cogan

> Fork independen dari **[proyek asli coolzyd9107](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS)**, dikelola oleh **[Cogan](https://github.com/cogan17)**. Repository ini **bukan** repository resmi pengembang utama.

[![Rilis](https://img.shields.io/github/v/release/cogan17/GKI_BakaSU_SUSFS?include_prereleases&label=Release)](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases)
[![Custom Build](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml/badge.svg)](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml)
[![Lisensi](https://img.shields.io/github/license/cogan17/GKI_BakaSU_SUSFS)](LICENSE)

**Tautan cepat:** [Actions](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions) · [Custom Build](.github/workflows/kernel-custom.yml) · [Build Kernel](.github/workflows/main.yml) · [Manual Release](.github/workflows/manual-release.yml) · [Releases](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases)

## Deskripsi Proyek

Repository ini membangun kernel Android GKI melalui GitHub Actions dengan **BakaSU + SUSFS** dan integrasi opsional seperti NoMount, ZRAM, BBG, serta Re-Kernel. Hasil build yang sukses menyediakan paket **AnyKernel3 ZIP**. Pilih `clean_build` untuk mengecualikan BakaSU, SUSFS, dan patch opsional.

**GKI/KMI tidak sama dengan versi Android OS yang terpasang.** Contohnya, perangkat Android 16 dapat memakai Android 14 GKI / Linux 6.1 jika KMI perangkat memang kompatibel. Pastikan KMI, kernel bawaan, dan kompatibilitas perangkat sebelum flashing; nomor versi Android yang sama saja tidak cukup.

## Pemberitahuan Penting

Ini adalah **fork Cogan yang dikelola secara independen**. Proyek asli dan dokumentasi Mandarin berasal dari [coolzyd9107/GKI_BakaSU_SUSFS](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS). Fork Cogan menambahkan perbaikan tampilan versi, workflow build, distribusi ZIP, dan dokumentasi. Catatan rilis di fork ini **bukan** pengumuman resmi upstream.

**Batasan dukungan:** Android 17 / 6.18 masih memiliki fitur terbatas; patch yang belum tersedia dari upstream akan dilewati. Kernel 5.10 dan 5.15 memiliki beberapa KMI Android; pastikan kamu memilih KMI yang tepat.

## KMI yang Didukung

| Android KMI | Seri Kernel | Pilihan `build_target` |
|---|---|---|
| Android 12 | 5.10 | `android12-5.10` |
| Android 13 | 5.10 | `android13-5.10` |
| Android 13 | 5.15 | `android13-5.15` |
| Android 14 | 5.15 | `android14-5.15` |
| Android 14 | 6.1 | `android14-6.1` |
| Android 15 | 6.6 | `android15-6.6` |
| Android 16 | 6.12 | `android16-6.12` |
| Android 17 | 6.18 | `android17-6.18` |

Versi 5.10 dan 5.15 sama-sama bersesuaian dengan beberapa KMI Android. Khususnya pada Android 13 dan Android 14 yang memiliki versi kernel yang sama untuk 5.15, KMI tidak dapat ditentukan secara otomatis hanya berdasarkan `5.15.xxx`; saat melakukan build dengan versi spesifik, Anda harus memilih versi Android yang sesuai secara manual. Kernel Android 17 / 6.18 saat ini telah mendukung build dasar, sementara beberapa komponen pendukung akan dilewati otomatis sesuai status dukungan hulunya (*upstream*).

## Menjalankan Build

### 1. Android Kernel Build - Custom (disarankan)

1. Buka **[Custom Build](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/kernel-custom.yml)**, pilih `main`, kemudian **Run workflow**.
2. Isi `android_version`, `kernel_version`, `sub_level`, `os_patch_level` (misalnya `lts`), dan `revision`.
3. Jika perlu, isi `version` (misalnya `Cogan`), `kernelsu_branch` (kosong untuk branch default BakaSU), dan `build_time` (`N` atau kosong untuk UTC saat build).
4. Pilih fitur sesuai perangkat, jalankan build, lalu unduh `*-AnyKernel3.zip` pada **Artifacts** dari run yang sukses.

**Contoh Cogan r7:** `android14` / `6.1` / `177` / `lts` / `r7`, label kustom `Cogan`. Ini bukan konfigurasi flashing yang berlaku untuk semua perangkat.

### 2. Build Kernel (matriks / filter versi)

Pada **[Build Kernel](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/main.yml)**, pilih satu `build_target` atau `all`. Kamu juga dapat mengaktifkan `build_kernel_version` dan memasukkan `6.6.66` atau filter seperti `6.6.X`. Untuk 5.10 / 5.15, isi pula `kernel_android_version`.

**Perhatian:** Workflow utama masih memakai nilai default `build_time` yang lama. Masukkan `N` agar menggunakan waktu UTC terbaru. Pada Custom Build, default sudah `N`.

### 3. Manual Release From Run

Gunakan **[Manual Release From Run](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/workflows/manual-release.yml)** untuk menerbitkan ZIP AnyKernel3 asli dari run yang sukses:

1. Buka workflow pada branch `main`.
2. Masukkan angka `source_run_id` dan pilih `Pre-Release` atau `Release`.
3. Workflow memvalidasi run sumber, integritas ZIP, dan file wajib, lalu melampirkan ZIP asli ke GitHub Releases tanpa repack.

**Penting:** Job rilis otomatis pada workflow utama saat ini dibatasi untuk repository lain; di fork Cogan gunakan Manual Release. Contoh: r7 [Run 38020806221](https://github.com/cogan17/GKI_BakaSU_SUSFS/actions/runs/38020806221) → [Release Cogan r7](https://github.com/cogan17/GKI_BakaSU_SUSFS/releases/tag/BakaSU-run-38020806221).

## Cabang BakaSU (BakaSU Branch)

Ketika `kernelsu_branch` dikosongkan, maka `main` yang akan digunakan. Anda juga dapat mengisi nama cabang jarak jauh (*remote branch*) BakaSU, atau commit SHA 40-digit lengkap. *Workflow* akan mengurai dan mengunci commit yang sesuai dengan cabang tersebut pada awal build, sehingga setiap KMI dalam eksekusi yang sama menggunakan kode yang sama; catatan rilis akan menautkan ke commit BakaSU yang benar-benar di-build.

## Fitur Build Opsional

| Opsi | Keterangan |
|---|---|
| `clean_build` | Tidak mengintegrasikan BakaSU, SUSFS, dan patch fitur opsional. |
| `cancel_susfs` | Mematikan integrasi SUSFS. SUSFS diaktifkan secara default; Android 17 / 6.18 belum memiliki cabang hulu dan akan dilewati secara otomatis. |
| `use_zram` | Mengaktifkan peningkatan ZRAM (LZ4KD). Android 17 / 6.18 belum memiliki patch terkait dan akan dilewati secara otomatis. |
| `use_bbg` | Mengaktifkan patch anti-reboot/anti-brick BBG. |
| `use_rekernel` | Mengaktifkan driver Re-Kernel, fitur masih dalam tahap pengujian. Untuk sementara dilewati pada Android 17 / 6.18 sampai repository ini beradaptasi dengan tata letak sumber baru hulu. |
| `cve_2026_43499_patch` | Menerapkan rantai perbaikan CVE-2026-43499, aktif secara default; 6.18 belum memiliki patch adaptasi di repository ini dan akan dilewati secara otomatis. |
| `build_bypass` | Membangun Bypass Image tambahan, yang disertakan dalam paket instalasi bersama Image biasa. |
| `droidspaces` | Memilih patch container Droidspaces: `off`, `678`, `123`, atau `345`. Versi 6.12 ke atas menggunakan patch generik hulu. |
| `droidspaces_ntsync` | Mengaktifkan NTSync dalam kombinasi yang didukung, mengharuskan Droidspaces diaktifkan secara bersamaan. Saat ini belum ada patch Android 17 / 6.18, kombinasi ini akan dilewati secara otomatis. |
| `use_nomount` | Integrasi NoMount. **Batasan saat ini:** workflow build yang digunakan bersama tetap menjalankan setup NoMount pada build non-clean meskipun opsi diatur ke `false`. Jangan mengandalkan opsi ini untuk menonaktifkannya sebelum workflow diperbaiki. |

**Tampilan versi:** Untuk Android 14 GKI / Linux 6.1 dengan nama kustom, fork Cogan memperpendek metadata compiler yang terlihat di Settings HyperOS tanpa menghilangkan struktur versi yang diperlukan parser. Waktu build otomatis menggunakan format `YYYY-MM-DD HH:mm:ss UTC`. Tampilan bisa berbeda antardevice.


Mode Bypass digunakan untuk menyelidiki masalah kompatibilitas versi modul kernel, bukan untuk melewati deteksi root. Saat diaktifkan, kompilasi penuh kedua akan dilakukan, yang menambah waktu build. Ikuti petunjuk skrip instalasi untuk memilih Image biasa atau Bypass Image saat melakukan flashing.

Patch Droidspaces bersifat eksperimental, perangkat dan versi kernel yang berbeda mungkin perlu mencoba slot yang berbeda. Android 16 / 6.12 dan Android 17 / 6.18 hanya memiliki satu jenis patch slot, pilih nilai apa pun selain `off`. Hulu kekurangan patch kompatibilitas NTSync untuk Android 14 / 5.15; kombinasi ini akan menyebabkan build gagal, harap tetap mematikannya. Android 17 / 6.18 akan otomatis melewati jika patch NTSync tidak ada.

## Artefak Build

Custom Build yang sukses menyediakan `*-AnyKernel3.zip` siap-flash. Artefak build saat ini tidak memerlukan ekstraksi ZIP kedua atau repack manual. Jika `build_bypass` diaktifkan, paket dapat memuat `Bypass-Image` tambahan.

### Contoh teruji: Cogan r7

- **Kernel:** `6.1.177-android14-11-Cogan` (Android 14 GKI / 6.1.177 LTS).
- **Perangkat uji:** Xiaomi 14T Pro (`2407FPN8EG`), Android 16 / HyperOS.
- **Sudah diperiksa:** kompilasi dan ZIP GitHub Actions sukses; versi kernel terbaca normal di HyperOS (tidak lagi `Unavailable`); BakaSU dan NoMount built-in terdeteksi oleh aplikasi pengelola.
- **Belum diuji menyeluruh:** semua patch opsional serta kompatibilitas pada perangkat atau ROM lain.

**Sebelum flashing:** periksa KMI sebenarnya, cadangkan partisi boot bawaan dan partisi lain yang mungkin berubah selama instalasi, lalu siapkan cara pemulihan yang aman. Gunakan kernel flasher yang kompatibel. Segala risiko menjadi tanggung jawab pengguna.

## Stock Config

Jika `config/stock_defconfig` ada di repository, build akan otomatis menggunakannya untuk penyamaran konfigurasi `/proc/config.gz`; jika file tidak ada, langkah ini dilewati. Anda dapat mengekstrak `/proc/config.gz` dari kernel resmi perangkat saat ini, mendekompresinya, meletakkannya di direktori ini, dan menamainya `stock_defconfig`.

## Sinkronisasi Data GKI

Workflow [Perbarui Data Versi GKI](.github/workflows/update-gki-data.yml) berjalan otomatis setiap hari Senin pukul UTC 08:00, dan juga dapat dipicu secara manual. Workflow menjalankan tes sinkronisasi, memperbarui JSON, memvalidasi matriks build, dan melakukan commit perubahan data.

## Ucapan Terima Kasih

- **Proyek asli dan pengembang utama:** [coolzyd9107 / GKI_BakaSU_SUSFS](https://github.com/coolzyd9107/GKI_BakaSU_SUSFS).
- **Pemeliharaan dan modifikasi fork Cogan:** [Cogan (cogan17)](https://github.com/cogan17).
- **Riwayat proyek dan kontributor:** [zzh20188](https://github.com/zzh20188), [zhuzhuzihan](https://github.com/zhuzhuzihan), [TanakaLun](https://github.com/TanakaLun), [luyancib](https://github.com/luyancib), [AlexLiuDev233](https://github.com/AlexLiuDev233), dan [cctv18](https://github.com/cctv18).
- Terima kasih kepada pengembang dan kontributor **BakaSU, KernelSU, SUSFS, NoMount, Re-Kernel, AnyKernel3**, dan Android GKI.

Repository ini menggunakan lisensi **GPL-2.0**. [Kanal Telegram upstream](https://t.me/BakaSUKernelBuilds) merupakan sumber komunitas asli, bukan kanal dukungan khusus fork Cogan.
