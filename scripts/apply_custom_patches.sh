#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR="${1:?用法: apply_custom_patches.sh <patch-directory>}"

if [[ ! -d "$PATCH_DIR" ]]; then
  echo "::error::自定义补丁目录不存在: $PATCH_DIR" >&2
  exit 1
fi

mapfile -d '' -t PATCH_FILES < <(
  find "$PATCH_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.patch' -print0 |
    LC_ALL=C sort -zV
)

if [[ ${#PATCH_FILES[@]} -eq 0 ]]; then
  echo "自定义补丁目录中没有 .patch 文件，跳过应用。"
  exit 0
fi

declare -A SEEN_SEQUENCES=()

for PATCH_FILE in "${PATCH_FILES[@]}"; do
  PATCH_NAME="$(basename -- "$PATCH_FILE")"

  if [[ ! "$PATCH_NAME" =~ ^([0-9]+)-.+\.patch$ ]]; then
    echo "::error::补丁文件名必须使用数字序号-描述.patch 格式: $PATCH_NAME" >&2
    exit 1
  fi

  SEQUENCE="${BASH_REMATCH[1]}"
  SEQUENCE_KEY="$(printf '%s' "$SEQUENCE" | sed 's/^0*//')"
  [[ -n "$SEQUENCE_KEY" ]] || SEQUENCE_KEY="0"

  if [[ -n "${SEEN_SEQUENCES[$SEQUENCE_KEY]:-}" ]]; then
    echo "::error::补丁序号重复: $PATCH_NAME 与 ${SEEN_SEQUENCES[$SEQUENCE_KEY]}" >&2
    exit 1
  fi

  SEEN_SEQUENCES["$SEQUENCE_KEY"]="$PATCH_NAME"
done

echo "发现 ${#PATCH_FILES[@]} 个自定义补丁，将按数字序号依次应用。"

for PATCH_FILE in "${PATCH_FILES[@]}"; do
  PATCH_NAME="$(basename -- "$PATCH_FILE")"
  echo "::group::检查并应用自定义补丁: $PATCH_NAME"

  if ! git apply --check "$PATCH_FILE"; then
    echo "::error::自定义补丁整体检查失败: $PATCH_NAME" >&2
    exit 1
  fi

  if ! git apply "$PATCH_FILE"; then
    echo "::error::自定义补丁应用失败: $PATCH_NAME" >&2
    exit 1
  fi

  echo "已应用: $PATCH_NAME"
  echo "::endgroup::"
done
