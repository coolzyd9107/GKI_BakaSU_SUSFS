"""Focused checks for GKI release tag synchronization."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import gki_fetch  # noqa: E402
import prepare_matrix  # noqa: E402
import update_data  # noqa: E402


def makefile(sublevel: int, patchlevel: int = 10) -> str:
    return f"VERSION = 5\nPATCHLEVEL = {patchlevel}\nSUBLEVEL = {sublevel}\n"


class ReleaseTagTests(unittest.TestCase):
    def test_git_confirms_missing_makefile_without_retry(self) -> None:
        with patch.object(gki_fetch.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "", "")) as run:
            self.assertIsNone(gki_fetch.fetch_git_makefile("abc123"))
        self.assertEqual(run.call_count, 3)
        self.assertIn("ls-tree", run.call_args.args[0])

    def test_unready_new_month_is_skipped_but_existing_month_fails(self) -> None:
        for existing in (False, True):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "5.10.json"
                original = json.dumps({
                    "android_version": "android12", "kernel_version": "5.10",
                    "entries": ([{"date": "2026-10", "kernel": "5.10.257"}] if existing else [])
                               + [{"date": "lts", "kernel": "5.10.257"}],
                })
                path.write_text(original)
                with (
                    patch.object(update_data, "json_path", return_value=str(path)),
                    patch.object(update_data, "fetch_latest_release_tags", return_value={}),
                    patch.object(update_data, "fetch_monthly_branches", return_value={"2026-10"}),
                    patch.object(update_data, "fetch_makefile", return_value=None),
                    patch.object(update_data, "fetch_lts", return_value=makefile(260)),
                ):
                    if existing:
                        with self.assertRaisesRegex(RuntimeError, "monthly branch has no Makefile"):
                            update_data.update_target("android12", "5.10", "2026-10", "2026-10", "")
                        self.assertEqual(path.read_text(), original)
                    else:
                        self.assertTrue(update_data.update_target("android12", "5.10", "2026-10", "2026-10", ""))
                        self.assertEqual(json.loads(path.read_text())["entries"],
                                         [{"date": "lts", "kernel": "5.10.260"}])

    def test_android17_618_target_and_matrix_data(self) -> None:
        self.assertEqual(gki_fetch.TARGETS[("android17", "6.18")][0], "2026-04")
        root = Path(__file__).resolve().parents[1]
        path = root / "data/android17/6.18.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        validated = prepare_matrix.validate_data(
            data, str(path), "android17", "6.18"
        )
        matrix = prepare_matrix.build_matrix(validated, deduplicate_sublevels=True)
        self.assertEqual(
            [item["sub_level"] for item in matrix], ["20", "21", "32", "33"]
        )

    def test_latest_revision_is_numeric_and_scoped_to_series(self) -> None:
        output = "\n".join(
            (
                "abc\trefs/tags/android13-5.10-2025-07_r2",
                "abc\trefs/tags/android13-5.10-2025-07_r10",
                "commit\trefs/tags/android13-5.10-2025-07_r10^{}",
                "abc\trefs/tags/android13-5.10-2025-10_r4",
                "abc\trefs/tags/android12-5.10-2025-07_r99",
            )
        )
        with patch.object(
            gki_fetch.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 0, output, ""),
        ):
            tags = gki_fetch.fetch_latest_release_tags("android13", "5.10")
        self.assertEqual(
            tags,
            {
                "2025-07": ("android13-5.10-2025-07_r10", "commit"),
                "2025-10": ("android13-5.10-2025-10_r4", "abc"),
            },
        )

    def test_missing_release_tags_fail_instead_of_assuming_r1(self) -> None:
        with patch.object(
            gki_fetch.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 0, "", ""),
        ):
            with self.assertRaises(gki_fetch.FetchError):
                gki_fetch.fetch_latest_release_tags("android13", "5.10")

    def test_remote_ref_listing_retries_transient_failure(self) -> None:
        output = "abc\trefs/tags/android13-5.10-2025-07_r4\n"
        with (
            patch.object(
                gki_fetch.subprocess,
                "run",
                side_effect=[
                    subprocess.CalledProcessError(128, ["git", "ls-remote"]),
                    subprocess.CompletedProcess([], 0, output, ""),
                ],
            ) as run,
            patch.object(gki_fetch.time, "sleep") as sleep,
        ):
            tags = gki_fetch.fetch_latest_release_tags("android13", "5.10")
        self.assertEqual(tags["2025-07"], ("android13-5.10-2025-07_r4", "abc"))
        self.assertEqual(run.call_count, 2)
        sleep.assert_called_once_with(2)

    def test_monthly_branches_include_deprecated(self) -> None:
        output = "\n".join(
            (
                "abc\trefs/heads/android12-5.10-2026-08",
                "abc\trefs/heads/deprecated/android12-5.10-2023-06",
                "abc\trefs/heads/android13-5.10-2026-08",
            )
        )
        with patch.object(
            gki_fetch.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 0, output, ""),
        ):
            branches = gki_fetch.fetch_monthly_branches("android12", "5.10")
        self.assertEqual(branches, {"2026-08", "2023-06"})

    def test_gitiles_failure_reads_exact_mirror_commit(self) -> None:
        ref = "refs/tags/android13-5.10-2025-07_r4"
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", False),
            patch.object(gki_fetch, "try_fetch", side_effect=gki_fetch.FetchError("503")),
            patch.object(gki_fetch.urllib.request, "urlopen", return_value=BytesIO(makefile(238).encode())) as urlopen,
        ):
            text = gki_fetch.fetch_ref_makefile(ref, "abc123")
        self.assertEqual(text, makefile(238))
        self.assertEqual(urlopen.call_args.args[0].full_url,
                         f"{gki_fetch.MIRROR_URL}/abc123/Makefile")

    def test_missing_mirror_commit_reads_google_git(self) -> None:
        ref = "refs/heads/android13-5.10-lts"
        missing = urllib.error.HTTPError("mirror", 404, "Not Found", None, None)
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", True),
            patch.object(gki_fetch, "list_remote_refs", return_value=f"abc123\t{ref}\n"),
            patch.object(gki_fetch.urllib.request, "urlopen", side_effect=missing),
            patch.object(gki_fetch, "fetch_git_makefile", return_value=makefile(260)) as fetch_git,
        ):
            text = gki_fetch.fetch_ref_makefile(ref)
        self.assertEqual(text, makefile(260))
        fetch_git.assert_called_once_with("abc123")

    def test_gitiles_404_for_existing_month_reads_exact_mirror_commit(self) -> None:
        ref = "refs/heads/android12-5.10-2026-10"
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", False),
            patch.object(gki_fetch, "try_fetch", return_value=None),
            patch.object(gki_fetch, "list_remote_refs", return_value=f"abc123\t{ref}\n"),
            patch.object(gki_fetch.urllib.request, "urlopen", return_value=BytesIO(makefile(257).encode())) as urlopen,
        ):
            self.assertEqual(gki_fetch.fetch_ref_makefile(ref), makefile(257))
            self.assertFalse(gki_fetch._gitiles_unavailable)
        self.assertEqual(urlopen.call_args.args[0].full_url,
                         f"{gki_fetch.MIRROR_URL}/abc123/Makefile")

    def test_gitiles_404_and_missing_ref_return_none(self) -> None:
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", False),
            patch.object(gki_fetch, "try_fetch", return_value=None),
            patch.object(gki_fetch, "list_remote_refs", return_value=""),
            patch.object(gki_fetch.urllib.request, "urlopen") as urlopen,
            patch.object(gki_fetch, "fetch_git_makefile") as fetch_git,
        ):
            self.assertIsNone(gki_fetch.fetch_ref_makefile("refs/heads/missing"))
        urlopen.assert_not_called()
        fetch_git.assert_not_called()

    def test_gitiles_404_and_mirror_404_read_pinned_git_commit(self) -> None:
        ref = "refs/tags/android13-5.10-2025-07_r4"
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", False),
            patch.object(gki_fetch, "try_fetch", return_value=None),
            patch.object(gki_fetch, "list_remote_refs") as list_refs,
            patch.object(gki_fetch.urllib.request, "urlopen", side_effect=
                         urllib.error.HTTPError("mirror", 404, "Not Found", None, None)),
            patch.object(gki_fetch, "fetch_git_makefile", return_value=makefile(238)) as fetch_git,
        ):
            self.assertEqual(gki_fetch.fetch_ref_makefile(ref, "abc123"), makefile(238))
        list_refs.assert_not_called()
        fetch_git.assert_called_once_with("abc123")

    def test_gitiles_404_does_not_hide_ref_lookup_failure(self) -> None:
        with (
            patch.object(gki_fetch, "_gitiles_unavailable", False),
            patch.object(gki_fetch, "try_fetch", return_value=None),
            patch.object(gki_fetch, "list_remote_refs", side_effect=gki_fetch.FetchError("network")),
        ):
            with self.assertRaises(gki_fetch.FetchError):
                gki_fetch.fetch_ref_makefile("refs/heads/android12-5.10-2026-10")

    def test_existing_revision_and_new_month_are_updated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "5.10.json"
            path.write_text(
                json.dumps(
                    {
                        "android_version": "android13",
                        "kernel_version": "5.10",
                        "entries": [
                            {"date": "2025-07", "kernel": "5.10.238", "revision": "r1"},
                            {"date": "2025-08", "kernel": "5.10.238", "revision": "r1"},
                            {"date": "lts", "kernel": "5.10.245", "revision": "r1"},
                        ],
                    }
                ),
                encoding="utf-8",
            )
            tags = {
                "2025-07": ("android13-5.10-2025-07_r4", "abc123"),
                "2025-10": ("android13-5.10-2025-10_r2", "def456"),
            }
            versions = {
                tags["2025-07"][0]: makefile(238),
                tags["2025-10"][0]: makefile(243),
            }
            with (
                patch.object(update_data, "json_path", return_value=str(path)),
                patch.object(update_data, "fetch_latest_release_tags", return_value=tags),
                patch.object(update_data, "fetch_monthly_branches", return_value={"2025-08", "2025-09"}),
                patch.object(update_data, "fetch_makefile", return_value=makefile(239)),
                patch.object(update_data, "fetch_tag_makefile", side_effect=lambda tag, sha: versions.get(tag)),
                patch.object(update_data, "fetch_lts", return_value=makefile(260)),
                patch.object(update_data.time, "sleep"),
            ):
                changed = update_data.update_target(
                    "android13", "5.10", "2025-07", "2025-10", ""
                )
            self.assertTrue(changed)
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(
                data["entries"],
                [
                    {"date": "2025-07", "kernel": "5.10.238", "revision": "r4"},
                    {"date": "2025-08", "kernel": "5.10.239"},
                    {"date": "2025-09", "kernel": "5.10.239"},
                    {"date": "2025-10", "kernel": "5.10.243", "revision": "r2"},
                    {"date": "lts", "kernel": "5.10.260"},
                ],
            )

    def test_same_revision_still_repairs_stale_kernel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "5.10.json"
            path.write_text(
                json.dumps(
                    {
                        "android_version": "android13",
                        "kernel_version": "5.10",
                        "entries": [
                            {"date": "2025-07", "kernel": "5.10.111", "revision": "r4"},
                            {"date": "lts", "kernel": "5.10.260"},
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with (
                patch.object(update_data, "json_path", return_value=str(path)),
                patch.object(update_data, "fetch_latest_release_tags", return_value={
                    "2025-07": ("android13-5.10-2025-07_r4", "abc123")
                }),
                patch.object(update_data, "fetch_monthly_branches", return_value=set()),
                patch.object(update_data, "fetch_tag_makefile", return_value=makefile(238)),
                patch.object(update_data, "fetch_lts", return_value=makefile(260)),
                patch.object(update_data.time, "sleep"),
            ):
                changed = update_data.update_target(
                    "android13", "5.10", "2025-07", "2025-07", ""
                )
            self.assertTrue(changed)
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data["entries"][0]["kernel"], "5.10.238")

    def test_missing_months_do_not_fetch_makefiles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "5.15.json"
            path.write_text(json.dumps({
                "android_version": "android13",
                "kernel_version": "5.15",
                "entries": [{"date": "2025-07", "kernel": "5.15.180"}],
                "lts": "5.15.200",
            }), encoding="utf-8")
            makefile_text = makefile(201, 15)
            with (
                patch.object(update_data, "json_path", return_value=str(path)),
                patch.object(update_data, "fetch_latest_release_tags", return_value={
                    "2025-07": ("android13-5.15-2025-07_r5", "abc123")
                }),
                patch.object(update_data, "fetch_monthly_branches", return_value={"2025-09"}),
                patch.object(update_data, "fetch_makefile", return_value=makefile_text) as fetch_makefile,
                patch.object(update_data, "fetch_tag_makefile", return_value=makefile(185, 15)),
                patch.object(update_data, "fetch_lts", return_value=makefile_text),
                patch.object(update_data.time, "sleep"),
            ):
                update_data.update_target("android13", "5.15", "2025-07", "2025-09", "")
            fetch_makefile.assert_called_once_with("android13", "5.15", "2025-09", "")
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data["entries"][0], {
                "date": "2025-07", "kernel": "5.15.185", "revision": "r5"
            })
            self.assertEqual(data["entries"][-1], {"date": "2025-09", "kernel": "5.15.201"})

    def test_android14_515_release_revision_is_independent(self) -> None:
        self.assertIn(("android14", "5.15"), gki_fetch.TARGETS)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "5.15.json"
            path.write_text(json.dumps({
                "android_version": "android14",
                "kernel_version": "5.15",
                "entries": [{"date": "2024-05", "kernel": "5.15.148"}],
                "lts": "5.15.195",
            }), encoding="utf-8")
            with (
                patch.object(update_data, "json_path", return_value=str(path)),
                patch.object(update_data, "fetch_latest_release_tags", return_value={
                    "2024-05": ("android14-5.15-2024-05_r25", "abc123")
                }),
                patch.object(update_data, "fetch_monthly_branches", return_value=set()),
                patch.object(update_data, "fetch_tag_makefile", return_value=makefile(148, 15)),
                patch.object(update_data, "fetch_lts", return_value=makefile(217, 15)),
                patch.object(update_data.time, "sleep"),
            ):
                changed = update_data.update_target(
                    "android14", "5.15", "2024-05", "2024-05", ""
                )
            self.assertTrue(changed)
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data["entries"], [{
                "date": "2024-05", "kernel": "5.15.148", "revision": "r25"
            }])
            self.assertEqual(data["lts"], "5.15.217")


if __name__ == "__main__":
    unittest.main()
