# 自定义内核补丁

将标准 unified diff 格式的补丁文件放在此目录。构建时需要在工作流输入中启用 `apply_custom_patches`；该选项默认关闭。

## 文件命名和应用顺序

文件名必须采用数字序号、连字符和描述的格式：

```text
0001-cve-fix.patch
0002-another-kernel-fix.patch
0010-custom-feature.patch
```

脚本按序号的数值从小到大应用，因此 `0010` 会排在 `0002` 之后。序号必须唯一，`1-fix.patch` 与 `0001-fix.patch` 会被视为重复序号。

## 一个补丁修改多个文件

同一个 `.patch` 文件可以包含多个 `diff --git` 文件段。把同一项修复涉及的所有文件变更放进一个补丁文件即可。

例如，某项漏洞修复同时修改：

- `net/ipv4/af_inet.c`
- `net/ipv4/tcp_ipv4.c`

应将这两个文件的 diff 放进同一个 `0001-cve-fix.patch`。脚本会先对整个补丁文件执行一次 `git apply --check`，通过后再执行一次 `git apply`，确保其中多个文件作为同一个补丁单元处理。

## 路径与适用范围

补丁路径以 Android 内核源码的 `common/` 目录为基准，例如：

```diff
diff --git a/net/ipv4/af_inet.c b/net/ipv4/af_inet.c
diff --git a/net/ipv4/tcp_ipv4.c b/net/ipv4/tcp_ipv4.c
```

启用后，目录中的补丁会应用到本次构建所选择的每个 KMI。请确认补丁适用于对应内核源码版本。任一补丁检查或应用失败都会终止该内核构建。

该选项独立于 Clean Build，可用于只构建原生内核并手动集成安全补丁。
