#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "::error::用法: apply_custom_patches.sh <patch-directory> [kernel-Makefile]" >&2
  exit 2
fi

PATCH_DIR="$1"
KERNEL_MAKEFILE="${2:-Makefile}"

if [[ ! -d "$PATCH_DIR" ]]; then
  echo "::error::自定义补丁目录不存在: $PATCH_DIR" >&2
  exit 1
fi

if [[ ! -f "$KERNEL_MAKEFILE" ]]; then
  echo "::error::内核 Makefile 不存在: $KERNEL_MAKEFILE" >&2
  exit 1
fi

if [[ -z "${SKIP_FAILED_CUSTOM_PATCHES:-}" &&
      -n "${GITHUB_EVENT_PATH:-}" &&
      -f "$GITHUB_EVENT_PATH" ]]; then
  SKIP_FAILED_CUSTOM_PATCHES="$(jq -r '.inputs.skip_failed_custom_patches // false' "$GITHUB_EVENT_PATH")"
fi
SKIP_FAILED_CUSTOM_PATCHES="${SKIP_FAILED_CUSTOM_PATCHES:-false}"

case "$SKIP_FAILED_CUSTOM_PATCHES" in
  true|false)
    ;;
  *)
    echo "::error::SKIP_FAILED_CUSTOM_PATCHES 只能设置为 true 或 false: $SKIP_FAILED_CUSTOM_PATCHES" >&2
    exit 2
    ;;
esac

if [[ -z "${CUSTOM_PATCH_SELECTION:-}" &&
      -n "${GITHUB_EVENT_PATH:-}" &&
      -f "$GITHUB_EVENT_PATH" ]]; then
  CUSTOM_PATCH_SELECTION="$(jq -r '.inputs.custom_patch_selection // "all"' "$GITHUB_EVENT_PATH")"
fi
CUSTOM_PATCH_SELECTION="${CUSTOM_PATCH_SELECTION:-all}"

if [[ -z "${APPLY_SELECTED_PATCHES:-}" &&
      -n "${GITHUB_EVENT_PATH:-}" &&
      -f "$GITHUB_EVENT_PATH" ]]; then
  APPLY_SELECTED_PATCHES="$(jq -r '(.inputs.apply_selected_patches // true) | tostring' "$GITHUB_EVENT_PATH")"
fi
APPLY_SELECTED_PATCHES="${APPLY_SELECTED_PATCHES:-true}"

case "$APPLY_SELECTED_PATCHES" in
  true|false)
    ;;
  *)
    echo "::error::APPLY_SELECTED_PATCHES 只能设置为 true 或 false: $APPLY_SELECTED_PATCHES" >&2
    exit 2
    ;;
esac

normalize_sequence() {
  local sequence="$1"

  while [[ ${#sequence} -gt 1 && "$sequence" == 0* ]]; do
    sequence="${sequence#0}"
  done

  printf '%s' "$sequence"
}

decimal_le() {
  local left="$1"
  local right="$2"

  if (( ${#left} < ${#right} )); then
    return 0
  fi

  if (( ${#left} > ${#right} )); then
    return 1
  fi

  [[ "$left" == "$right" || "$left" < "$right" ]]
}

declare -a SELECTION_STARTS=()
declare -a SELECTION_ENDS=()
SELECTION_ALL=false

if [[ "$CUSTOM_PATCH_SELECTION" == "all" ]]; then
  SELECTION_ALL=true
else
  if [[ -z "$CUSTOM_PATCH_SELECTION" ||
        "$CUSTOM_PATCH_SELECTION" == ,* ||
        "$CUSTOM_PATCH_SELECTION" == *, ||
        "$CUSTOM_PATCH_SELECTION" == *,,* ||
        "$CUSTOM_PATCH_SELECTION" == *[[:space:]]* ]]; then
    echo "::error::补丁序号格式无效: $CUSTOM_PATCH_SELECTION" >&2
    exit 2
  fi

  IFS=',' read -r -a SELECTION_ITEMS <<< "$CUSTOM_PATCH_SELECTION"
  if [[ ${#SELECTION_ITEMS[@]} -eq 0 ]]; then
    echo "::error::补丁序号不能为空。" >&2
    exit 2
  fi

  for selection_item in "${SELECTION_ITEMS[@]}"; do
    if [[ "$selection_item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      selection_start="$(normalize_sequence "${BASH_REMATCH[1]}")"
      selection_end="$(normalize_sequence "${BASH_REMATCH[2]}")"
    elif [[ "$selection_item" =~ ^[0-9]+$ ]]; then
      selection_start="$(normalize_sequence "$selection_item")"
      selection_end="$selection_start"
    else
      echo "::error::补丁序号格式无效: $selection_item" >&2
      exit 2
    fi

    if ! decimal_le "$selection_start" "$selection_end"; then
      echo "::error::补丁序号范围的起始值不能大于结束值: $selection_item" >&2
      exit 2
    fi

    SELECTION_STARTS+=("$selection_start")
    SELECTION_ENDS+=("$selection_end")
  done
fi

sequence_is_selected() {
  local sequence_key
  local selection_index

  sequence_key="$(normalize_sequence "$1")"

  if [[ "$SELECTION_ALL" == "true" ]]; then
    return 0
  fi

  for selection_index in "${!SELECTION_STARTS[@]}"; do
    if decimal_le "${SELECTION_STARTS[$selection_index]}" "$sequence_key" &&
       decimal_le "$sequence_key" "${SELECTION_ENDS[$selection_index]}"; then
      return 0
    fi
  done

  return 1
}

mapfile -d '' -t PATCH_FILES < <(
  find "$PATCH_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.patch' -print0 |
    LC_ALL=C sort -zV
)

if [[ ${#PATCH_FILES[@]} -eq 0 ]]; then
  echo "自定义补丁目录中没有 .patch 文件，跳过应用。"
  exit 0
fi

if ! CURRENT_VERSION="$(awk '
  $1 == "VERSION" && $2 == "=" { version = $3 }
  $1 == "PATCHLEVEL" && $2 == "=" { patchlevel = $3 }
  $1 == "SUBLEVEL" && $2 == "=" { sublevel = $3 }
  END {
    if (version !~ /^[0-9]+$/ ||
        patchlevel !~ /^[0-9]+$/ ||
        sublevel !~ /^[0-9]+$/) {
      exit 1
    }
    printf "%s.%s.%s\n", version, patchlevel, sublevel
  }
' "$KERNEL_MAKEFILE")"; then
  echo "::error::无法从内核 Makefile 读取 VERSION、PATCHLEVEL 和 SUBLEVEL: $KERNEL_MAKEFILE" >&2
  exit 1
fi

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$ ]]; then
  echo "::error::内核 Makefile 中的版本格式无效: $CURRENT_VERSION" >&2
  exit 1
fi

is_valid_version() {
  [[ "$1" =~ ^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$ ]]
}

version_le() {
  local ordered_versions
  local first_version

  ordered_versions="$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort -V)"
  first_version="${ordered_versions%%$'\n'*}"
  [[ "$first_version" == "$1" ]]
}

version_ranges_overlap() {
  local min_a="$1"
  local max_a="$2"
  local min_b="$3"
  local max_b="$4"

  if [[ "$max_a" != "all" && "$min_b" != "all" ]] &&
     ! version_le "$min_b" "$max_a"; then
    return 1
  fi

  if [[ "$max_b" != "all" && "$min_a" != "all" ]] &&
     ! version_le "$min_a" "$max_b"; then
    return 1
  fi

  return 0
}

declare -a PATCH_SEQUENCES=()
declare -a PATCH_MIN_VERSIONS=()
declare -a PATCH_MAX_VERSIONS=()
declare -a PATCH_NAMES=()

for PATCH_FILE in "${PATCH_FILES[@]}"; do
  PATCH_NAME="$(basename -- "$PATCH_FILE")"

  if [[ ! "$PATCH_NAME" =~ ^([0-9]+)-(all|[0-9]+\.[0-9]+\.[0-9]+)-(all|[0-9]+\.[0-9]+\.[0-9]+)-(.+)\.patch$ ]]; then
    echo "::error::补丁文件名格式无效，应为 顺序-最低版本-最高版本-名字.patch: $PATCH_NAME" >&2
    exit 1
  fi

  SEQUENCE="${BASH_REMATCH[1]}"
  MIN_VERSION="${BASH_REMATCH[2]}"
  MAX_VERSION="${BASH_REMATCH[3]}"

  SEQUENCE_KEY="$SEQUENCE"
  while [[ ${#SEQUENCE_KEY} -gt 1 && "$SEQUENCE_KEY" == 0* ]]; do
    SEQUENCE_KEY="${SEQUENCE_KEY#0}"
  done

  if [[ "$MIN_VERSION" == "all" || "$MAX_VERSION" == "all" ]]; then
    if [[ "$MIN_VERSION" != "all" || "$MAX_VERSION" != "all" ]]; then
      echo "::error::无版本限制时，最低版本和最高版本必须同时填写 all: $PATCH_NAME" >&2
      exit 1
    fi
  else
    if ! is_valid_version "$MIN_VERSION" || ! is_valid_version "$MAX_VERSION"; then
      echo "::error::补丁版本范围必须使用完整的 主版本.次版本.补丁版本 格式: $PATCH_NAME" >&2
      exit 1
    fi

    if ! version_le "$MIN_VERSION" "$MAX_VERSION"; then
      echo "::error::补丁最低版本高于最高版本: $PATCH_NAME" >&2
      exit 1
    fi
  fi

  for index in "${!PATCH_SEQUENCES[@]}"; do
    if [[ "${PATCH_SEQUENCES[$index]}" == "$SEQUENCE_KEY" ]] &&
       version_ranges_overlap \
         "${PATCH_MIN_VERSIONS[$index]}" \
         "${PATCH_MAX_VERSIONS[$index]}" \
         "$MIN_VERSION" \
         "$MAX_VERSION"; then
      echo "::error::相同顺序号的补丁版本范围存在重叠: ${PATCH_NAMES[$index]} 与 $PATCH_NAME" >&2
      exit 1
    fi
  done

  PATCH_SEQUENCES+=("$SEQUENCE_KEY")
  PATCH_MIN_VERSIONS+=("$MIN_VERSION")
  PATCH_MAX_VERSIONS+=("$MAX_VERSION")
  PATCH_NAMES+=("$PATCH_NAME")
done

echo "当前内核版本: $CURRENT_VERSION"
echo "补丁序号筛选: $CUSTOM_PATCH_SELECTION"
if [[ "$APPLY_SELECTED_PATCHES" == "true" ]]; then
  echo "筛选模式: 仅应用所选序号"
else
  echo "筛选模式: 跳过所选序号"
fi
echo "跳过失败补丁: $SKIP_FAILED_CUSTOM_PATCHES"
echo "发现 ${#PATCH_FILES[@]} 个自定义补丁，已完成文件名、版本范围和顺序检查。"

SNAPSHOT_BASE="${RUNNER_TEMP:-$PWD}"
SNAPSHOT_DIR="$(mktemp -d "$SNAPSHOT_BASE/custom-patch-snapshots.XXXXXX")"
trap 'rm -rf -- "$SNAPSHOT_DIR"' EXIT

APPLIED_COUNT=0
ALREADY_PRESENT_COUNT=0
VERSION_SKIPPED_COUNT=0
SEQUENCE_SKIPPED_COUNT=0
FAILED_COUNT=0
FAILED_SKIPPED_COUNT=0
declare -a FAILED_PATCH_NAMES=()

log_patch_failure() {
  local failure_phase="$1"
  local failure_status="$2"
  local failure_command="$3"
  local failure_output="$4"

  FAILED_COUNT=$((FAILED_COUNT + 1))
  FAILED_PATCH_NAMES+=("$PATCH_NAME")

  echo "::endgroup::"
  echo "======================================================================"
  echo "::group::自定义补丁失败诊断: $PATCH_NAME"
  echo "::warning title=自定义补丁应用失败::$PATCH_NAME；阶段: $failure_phase；退出码: $failure_status"

  echo "补丁文件: $PATCH_FILE"
  echo "补丁文件 SHA256: $(sha256sum "$PATCH_FILE" | awk '{print $1}')"
  echo "补丁文件大小: $(wc -c < "$PATCH_FILE" | tr -d ' ') bytes"
  echo "当前内核版本: $CURRENT_VERSION"
  echo "补丁适用范围: $MIN_VERSION <= currentVer <= $MAX_VERSION"
  echo "失败阶段: $failure_phase"
  echo "失败命令: $failure_command"
  echo "命令退出码: $failure_status"
  echo "跳过失败补丁开关: $SKIP_FAILED_CUSTOM_PATCHES"

  echo
  echo "受影响文件:"
  if [[ ${#AFFECTED_FILES[@]} -eq 0 ]]; then
    echo "无法从补丁中提取受影响文件。"
  else
    for relative_path in "${AFFECTED_FILES[@]}"; do
      echo "  - $relative_path"
    done
  fi

  echo
  echo "命令完整输出:"
  if [[ -n "$failure_output" ]]; then
    printf '%s\n' "$failure_output"
  else
    echo "(命令没有输出)"
  fi

  echo
  echo "补丁文件开头（最多 80 行）:"
  head -n 80 "$PATCH_FILE"

  echo
  echo "源码 Git 状态:"
  git status --short

  if [[ ${#AFFECTED_FILES[@]} -gt 0 ]]; then
    for relative_path in "${AFFECTED_FILES[@]}"; do
      echo
      echo "源码差异: $relative_path"
      git diff --no-ext-diff --no-color -- "$relative_path"
    done
  fi

  echo
  echo "======================================================================"
  if [[ "$SKIP_FAILED_CUSTOM_PATCHES" == "true" ]]; then
    FAILED_SKIPPED_COUNT=$((FAILED_SKIPPED_COUNT + 1))
    echo "::warning::已跳过失败补丁，继续处理后续补丁: $PATCH_NAME"
    echo "::endgroup::"
    echo "======================================================================"
    return 0
  fi

  echo "::error::自定义补丁失败，已按设置终止当前构建: $PATCH_NAME"
  echo "::endgroup::"
  echo "======================================================================"
  return 1
}

for index in "${!PATCH_FILES[@]}"; do
  PATCH_FILE="${PATCH_FILES[$index]}"
  PATCH_NAME="${PATCH_NAMES[$index]}"
  SEQUENCE="${PATCH_SEQUENCES[$index]}"
  MIN_VERSION="${PATCH_MIN_VERSIONS[$index]}"
  MAX_VERSION="${PATCH_MAX_VERSIONS[$index]}"
  AFFECTED_FILES=()

  if [[ "$MIN_VERSION" != "all" ]] &&
     { ! version_le "$MIN_VERSION" "$CURRENT_VERSION" ||
       ! version_le "$CURRENT_VERSION" "$MAX_VERSION"; }; then
    echo "::group::跳过自定义补丁: $PATCH_NAME"
    echo "当前内核版本: $CURRENT_VERSION"
    echo "补丁适用范围: $MIN_VERSION <= currentVer <= $MAX_VERSION"
    echo "跳过原因: 当前内核版本不在补丁适用范围内。"
    echo "======================================================================"
    echo "::endgroup::"
    echo "======================================================================"
    VERSION_SKIPPED_COUNT=$((VERSION_SKIPPED_COUNT + 1))
    continue
  fi

  if sequence_is_selected "$SEQUENCE"; then
    SEQUENCE_SELECTED=true
  else
    SEQUENCE_SELECTED=false
  fi

  if [[ "$APPLY_SELECTED_PATCHES" == "true" && "$SEQUENCE_SELECTED" != "true" ]] ||
     [[ "$APPLY_SELECTED_PATCHES" == "false" && "$SEQUENCE_SELECTED" == "true" ]]; then
    echo "::group::跳过自定义补丁（序号筛选）: $PATCH_NAME"
    echo "顺序号: $SEQUENCE"
    echo "当前内核版本: $CURRENT_VERSION"
    if [[ "$APPLY_SELECTED_PATCHES" == "true" ]]; then
      echo "跳过原因: 当前模式只应用输入框中选择的补丁序号。"
    else
      echo "跳过原因: 当前补丁序号位于输入框指定的跳过范围内。"
    fi
    echo "======================================================================"
    echo "::endgroup::"
    echo "======================================================================"
    SEQUENCE_SKIPPED_COUNT=$((SEQUENCE_SKIPPED_COUNT + 1))
    continue
  fi

  echo "::group::✔ 应用自定义补丁: $PATCH_NAME"
  echo "顺序号: $SEQUENCE"
  echo "当前内核版本: $CURRENT_VERSION"
  echo "补丁适用范围: $MIN_VERSION <= currentVer <= $MAX_VERSION"

  if PATCH_NUMSTAT="$(git apply --numstat "$PATCH_FILE" 2>&1)"; then
    :
  else
    PATCH_EXIT_CODE=$?
    if ! log_patch_failure \
      "读取补丁文件列表" \
      "$PATCH_EXIT_CODE" \
      "git apply --numstat $PATCH_FILE" \
      "$PATCH_NUMSTAT"; then
      exit 1
    fi
    continue
  fi

  if [[ -z "$PATCH_NUMSTAT" ]]; then
    if ! log_patch_failure \
      "读取补丁文件列表" \
      1 \
      "git apply --numstat $PATCH_FILE" \
      "补丁没有包含任何文件修改。"; then
      exit 1
    fi
    continue
  fi

  while IFS=$'\t' read -r added deleted relative_path; do
    [[ -n "$relative_path" ]] && AFFECTED_FILES+=("$relative_path")
  done <<< "$PATCH_NUMSTAT"

  if [[ ${#AFFECTED_FILES[@]} -eq 0 ]]; then
    if ! log_patch_failure \
      "提取补丁涉及文件" \
      1 \
      "解析 git apply --numstat 输出" \
      "无法从补丁中提取受影响文件。"; then
      exit 1
    fi
    continue
  fi

  echo "涉及文件:"
  for relative_path in "${AFFECTED_FILES[@]}"; do
    case "$relative_path" in
      /*|..|../*|*/../*|*/..)
        echo "::error::补丁包含源码目录之外的路径: $relative_path" >&2
        exit 1
        ;;
    esac
    echo "  - $relative_path"
  done

  if PATCH_REVERSE_CHECK_OUTPUT="$(patch --batch --reverse --dry-run -p1 < "$PATCH_FILE" 2>&1)"; then
    echo "::endgroup::"
    echo "======================================================================"
    echo "::group::✔ 自定义补丁已存在: $PATCH_NAME"
    echo "当前源码已经包含该补丁的全部修改，跳过重复应用。"
    echo "$PATCH_REVERSE_CHECK_OUTPUT"
    echo "======================================================================"
    echo "::endgroup::"
    echo "======================================================================"
    ALREADY_PRESENT_COUNT=$((ALREADY_PRESENT_COUNT + 1))
    continue
  fi

  if PATCH_CHECK_OUTPUT="$(git apply --verbose --check "$PATCH_FILE" 2>&1)"; then
    echo "$PATCH_CHECK_OUTPUT"
    echo "补丁检查通过。"
  else
    PATCH_EXIT_CODE=$?
    if ! log_patch_failure \
      "预检查" \
      "$PATCH_EXIT_CODE" \
      "git apply --verbose --check $PATCH_FILE" \
      "$PATCH_CHECK_OUTPUT"; then
      exit 1
    fi
    continue
  fi

  PATCH_SNAPSHOT_DIR="$SNAPSHOT_DIR/$index"
  mkdir -p "$PATCH_SNAPSHOT_DIR/before" "$PATCH_SNAPSHOT_DIR/after"

  BEFORE_FILES=()
  AFTER_FILES=()
  BEFORE_EXISTS=()

  for file_index in "${!AFFECTED_FILES[@]}"; do
    relative_path="${AFFECTED_FILES[$file_index]}"
    before_file="$PATCH_SNAPSHOT_DIR/before/$file_index"

    if [[ -f "$relative_path" ]]; then
      cp -- "$relative_path" "$before_file"
      BEFORE_FILES+=("$before_file")
      BEFORE_EXISTS+=(true)
    else
      BEFORE_FILES+=(/dev/null)
      BEFORE_EXISTS+=(false)
    fi
  done

  if PATCH_APPLY_OUTPUT="$(git apply --verbose "$PATCH_FILE" 2>&1)"; then
    if [[ -n "$PATCH_APPLY_OUTPUT" ]]; then
      echo "$PATCH_APPLY_OUTPUT"
    fi
  else
    PATCH_EXIT_CODE=$?

    for file_index in "${!AFFECTED_FILES[@]}"; do
      relative_path="${AFFECTED_FILES[$file_index]}"
      if [[ "${BEFORE_EXISTS[$file_index]}" == "true" ]]; then
        cp -p -- "${BEFORE_FILES[$file_index]}" "$relative_path"
      else
        rm -f -- "$relative_path"
      fi
    done

    if ! log_patch_failure \
      "应用补丁" \
      "$PATCH_EXIT_CODE" \
      "git apply --verbose $PATCH_FILE" \
      "$PATCH_APPLY_OUTPUT"; then
      exit 1
    fi
    continue
  fi

  for file_index in "${!AFFECTED_FILES[@]}"; do
    relative_path="${AFFECTED_FILES[$file_index]}"
    after_file="$PATCH_SNAPSHOT_DIR/after/$file_index"

    if [[ -f "$relative_path" ]]; then
      cp -- "$relative_path" "$after_file"
      AFTER_FILES+=("$after_file")
    else
      AFTER_FILES+=(/dev/null)
    fi
  done

  echo
  echo "应用前后代码差异:"
  echo "说明: - 行表示应用前的代码，+ 行表示应用后的代码；上下文行用于定位修改区域。"
  echo "以下内容只展示实际代码差异，不包含补丁文件开头的说明文字。"

  for file_index in "${!AFFECTED_FILES[@]}"; do
    relative_path="${AFFECTED_FILES[$file_index]}"
    echo
    echo "---------- $relative_path ----------"

    if diff -u \
      --label "before/$relative_path" \
      --label "after/$relative_path" \
      "${BEFORE_FILES[$file_index]}" \
      "${AFTER_FILES[$file_index]}"; then
      echo "::warning::补丁声明了该文件，但没有产生可显示的文本差异: $relative_path"
    else
      DIFF_STATUS=$?
      if (( DIFF_STATUS > 1 )); then
        echo "::error::无法生成补丁前后差异: $relative_path" >&2
        exit "$DIFF_STATUS"
      fi
    fi
  done

  echo
  echo "✔ 应用自定义补丁: $PATCH_NAME"
  echo "======================================================================"
  echo "::endgroup::"
  echo "======================================================================"

  APPLIED_COUNT=$((APPLIED_COUNT + 1))
done

echo "自定义补丁处理完成。"
echo "当前内核: $CURRENT_VERSION"
echo "成功应用: $APPLIED_COUNT"
echo "源码已包含: $ALREADY_PRESENT_COUNT"
echo "版本范围跳过: $VERSION_SKIPPED_COUNT"
echo "序号筛选跳过: $SEQUENCE_SKIPPED_COUNT"
echo "应用失败: $FAILED_COUNT"
echo "失败后跳过: $FAILED_SKIPPED_COUNT"

if [[ ${#FAILED_PATCH_NAMES[@]} -gt 0 ]]; then
  echo "::warning::以下自定义补丁应用失败:"
  for failed_patch in "${FAILED_PATCH_NAMES[@]}"; do
    echo "  - $failed_patch"
  done
fi

if (( FAILED_COUNT > 0 )) && [[ "$SKIP_FAILED_CUSTOM_PATCHES" != "true" ]]; then
  exit 1
fi
