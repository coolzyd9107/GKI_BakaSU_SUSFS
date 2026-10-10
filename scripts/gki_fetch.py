import base64
import binascii
import http.client
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

GIT_URL = "https://android.googlesource.com/kernel/common"
MIRROR_URL = "https://raw.githubusercontent.com/aosp-mirror/kernel_common"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
_gitiles_unavailable = False

# (android版本, 内核版本): (起始日期, 结束日期, deprecated截止日期)
# 结束日期为 None 表示活跃版本，运行时自动使用当前月份
TARGETS = {
    ("android12", "5.10"): ("2021-08", None,       "2024-08"),
    ("android13", "5.10"): ("2022-05", None,       "2024-09"),
    ("android13", "5.15"): ("2022-06", None,       "2024-09"),
    ("android14", "5.15"): ("2023-06", None,       "2024-09"),
    ("android14", "6.1"):  ("2023-06", None,       "2024-09"),
    ("android15", "6.6"):  ("2024-10", None,       ""),
    ("android16", "6.12"): ("2025-06", None,       ""),
    ("android17", "6.18"): ("2026-04", None,       ""),
}

TRANSIENT_ERRORS = (
    urllib.error.URLError,
    TimeoutError,
    http.client.RemoteDisconnected,
    ConnectionResetError,
    OSError,
    binascii.Error,
)


class FetchError(RuntimeError):
    """Raised when an upstream request fails after retries."""


def get_end_date(end: str | None) -> str:
    """返回结束日期：如果为 None 则使用当前月份"""
    if end is not None:
        return end
    return datetime.now(timezone.utc).strftime("%Y-%m")


def make_date_range(start: str, end: str) -> list[str]:
    """生成从 start 到 end 的 YYYY-MM 列表"""
    sy, sm = map(int, start.split("-"))
    ey, em = map(int, end.split("-"))
    dates = []
    y, m = sy, sm
    while (y, m) <= (ey, em):
        dates.append(f"{y}-{m:02d}")
        m += 1
        if m > 12:
            m = 1
            y += 1
    return dates


def try_fetch(url: str, attempts: int = 3) -> str | None:
    """Fetch and decode a googlesource file; return None only for HTTP 404."""
    request = urllib.request.Request(url, headers={"User-Agent": "GKI-data-updater"})
    last_error: BaseException | None = None

    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                encoded = b"".join(response.read().split())
                content = base64.b64decode(encoded, validate=True)
                return content.decode("utf-8", errors="replace")
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            last_error = error
        except TRANSIENT_ERRORS as error:
            last_error = error

        if attempt < attempts:
            time.sleep(attempt)

    raise FetchError(f"failed to fetch {url}: {last_error}")


def fetch_git_makefile(ref: str) -> str | None:
    """Read one Makefile through Git when Gitiles and the mirror are unavailable."""
    last_error: BaseException | None = None
    for attempt in range(1, 4):
        try:
            with tempfile.TemporaryDirectory(prefix="gki-makefile-") as directory:
                subprocess.run(
                    ["git", "init", "-q", directory],
                    check=True, capture_output=True, text=True, timeout=30,
                )
                subprocess.run(
                    ["git", "-C", directory, "fetch", "--quiet", "--depth=1",
                     "--filter=tree:0", "--no-tags", GIT_URL, ref],
                    check=True, capture_output=True, text=True, timeout=120,
                )
                listing = subprocess.run(
                    ["git", "-C", directory, "ls-tree", "--name-only", "FETCH_HEAD", "--", "Makefile"],
                    check=True, capture_output=True, text=True, timeout=120,
                )
                if not listing.stdout.strip():
                    return None
                result = subprocess.run(
                    ["git", "-C", directory, "show", "FETCH_HEAD:Makefile"],
                    check=True, capture_output=True, text=True, timeout=120,
                )
                return result.stdout
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            last_error = error
            if attempt < 3:
                time.sleep(attempt * 2)
    detail = getattr(last_error, "stderr", None) or str(last_error)
    raise FetchError(f"failed to read Makefile at {ref} via git: {detail}") from last_error


def fetch_ref_makefile(ref: str, sha: str | None = None) -> str | None:
    """Read a ref; verify Gitiles 404s through Git before declaring it absent."""
    global _gitiles_unavailable
    if not _gitiles_unavailable:
        url = f"{GIT_URL}/+/{ref}/Makefile?format=TEXT"
        try:
            text = try_fetch(url)
            if text is not None:
                return text
            # Gitiles can return 404 for a ref advertised by Git. Verify the
            # ref and use the same fallback as a service failure in that case.
        except FetchError as error:
            _gitiles_unavailable = True
            print(f"Gitiles unavailable ({error}); trying other sources", file=sys.stderr)

    if sha is None:
        kind = "--tags" if ref.startswith("refs/tags/") else "--heads"
        refs = list_remote_refs(kind, ref)
        resolved = dict(line.split("\t", 1)[::-1] for line in refs.splitlines())
        sha = resolved.get(f"{ref}^{{}}") or resolved.get(ref)
        if sha is None:
            return None

    mirror_request = urllib.request.Request(
        f"{MIRROR_URL}/{sha}/Makefile", headers={"User-Agent": "GKI-data-updater"}
    )
    try:
        with urllib.request.urlopen(mirror_request, timeout=20) as response:
            return response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        error.close()
        return fetch_git_makefile(sha)
    except TRANSIENT_ERRORS:
        return fetch_git_makefile(sha)


def fetch_makefile(android_ver: str, kernel_ver: str, date: str,
                   dep_cutoff: str) -> str | None:
    """获取日期分支 Makefile，优先尝试预期路径，失败则回退"""
    branch = f"{android_ver}-{kernel_ver}-{date}"
    if dep_cutoff and date <= dep_cutoff:
        paths = [f"deprecated/{branch}", branch]
    else:
        paths = [branch, f"deprecated/{branch}"]

    for p in paths:
        text = fetch_ref_makefile(f"refs/heads/{p}")
        if text is not None:
            return text
        time.sleep(0.3)
    return None


def fetch_lts(android_ver: str, kernel_ver: str) -> str | None:
    """获取 LTS 分支 Makefile"""
    lts_branch = f"{android_ver}-{kernel_ver}-lts"
    return fetch_ref_makefile(f"refs/heads/{lts_branch}")


def list_remote_refs(kind: str, *patterns: str) -> str:
    """List upstream refs with retries for transient network failures."""
    last_error: BaseException | None = None
    for attempt in range(1, 4):
        try:
            result = subprocess.run(
                ["git", "ls-remote", kind, GIT_URL, *patterns],
                check=True,
                capture_output=True,
                text=True,
                timeout=90,
            )
            return result.stdout
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            last_error = error
            if attempt < 3:
                time.sleep(attempt * 2)
    raise FetchError(f"failed to list upstream refs {patterns}: {last_error}")


def fetch_latest_release_tags(android_ver: str, kernel_ver: str) -> dict[str, tuple[str, str]]:
    """Find the highest released revision for each monthly branch."""
    prefix = f"{android_ver}-{kernel_ver}-"
    pattern = re.compile(
        rf"^refs/tags/{re.escape(prefix)}(\d{{4}}-\d{{2}})_r(\d+)$"
    )
    refs = list_remote_refs("--tags", f"refs/tags/{prefix}*_r*")
    peeled = {}
    for line in refs.splitlines():
        sha, _, ref = line.partition("\t")
        if ref.endswith("^{}"):
            peeled[ref.removesuffix("^{}")] = sha
    latest: dict[str, tuple[int, str, str]] = {}
    for line in refs.splitlines():
        sha, _, ref = line.partition("\t")
        match = pattern.fullmatch(ref)
        if match is None:
            continue
        date, revision = match.group(1), int(match.group(2))
        tag = ref.removeprefix("refs/tags/")
        if date not in latest or revision > latest[date][0]:
            latest[date] = (revision, tag, peeled.get(ref, sha))
    if not latest:
        raise FetchError(f"no monthly release tags found for {prefix}")
    return {date: (tag, sha) for date, (_, tag, sha) in latest.items()}


def fetch_monthly_branches(android_ver: str, kernel_ver: str) -> set[str]:
    """Find monthly branches, including ones moved under deprecated/."""
    prefix = f"{android_ver}-{kernel_ver}-"
    pattern = re.compile(
        rf"^refs/heads/(?:deprecated/)?{re.escape(prefix)}(\d{{4}}-\d{{2}})$"
    )
    refs = list_remote_refs(
        "--heads",
        f"refs/heads/{prefix}20*",
        f"refs/heads/deprecated/{prefix}20*",
    )
    branches = set()
    for line in refs.splitlines():
        _, _, ref = line.partition("\t")
        match = pattern.fullmatch(ref)
        if match is not None:
            branches.add(match.group(1))
    return branches


def fetch_tag_makefile(tag: str, sha: str) -> str:
    """Read the Makefile from the exact release tag used for its revision."""
    text = fetch_ref_makefile(f"refs/tags/{tag}", sha)
    if text is None:
        raise FetchError(f"release tag has no Makefile: {tag}")
    return text


def parse_version(makefile_text: str) -> tuple[str, str, str] | None:
    """从 Makefile 提取 VERSION, PATCHLEVEL, SUBLEVEL"""
    vals = {}
    for key in ("VERSION", "PATCHLEVEL", "SUBLEVEL"):
        m = re.search(rf"^{key}\s*=\s*(\d+)", makefile_text, re.MULTILINE)
        if not m:
            return None
        vals[key] = m.group(1)
    return vals["VERSION"], vals["PATCHLEVEL"], vals["SUBLEVEL"]


def json_path(android_ver: str, kernel_ver: str) -> str:
    """返回对应的 JSON 文件路径"""
    return os.path.join(DATA_DIR, android_ver, f"{kernel_ver}.json")
