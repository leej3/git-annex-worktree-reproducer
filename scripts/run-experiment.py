#!/usr/bin/env python3
"""Compile and compare the pinned source and patch using disposable containers."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(args, expected=0):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if result.returncode != expected:
        sys.stderr.write(result.stdout + result.stderr)
        raise RuntimeError(f"Expected exit {expected}, got {result.returncode}: {args}")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="docker")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--output", type=Path, default=ROOT / "results/compiled-comparison.json")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "sources/manifest.json").read_text())
    assert digest(ROOT / "sources" / manifest["git_annex"]["archive"]) == manifest["git_annex"]["sha256"]
    assert digest(ROOT / manifest["patch"]["path"]) == manifest["patch"]["sha256"]
    image = "git-annex-worktree-fix"
    if not args.skip_build:
        subprocess.run([args.engine, "build", "--platform", "linux/amd64", "-t", image,
                        "-f", "Containerfile.build", "."], cwd=ROOT, check=True)
    prefix = [args.engine, "run", "--rm", "--platform", "linux/amd64", image]
    embedded = json.loads(run(prefix + ["cat", "/provenance/manifest.json"]).stdout)
    assert embedded == manifest, "Image source/patch manifest differs from this checkout"
    image_inputs = {"/provenance/Containerfile.build": "Containerfile.build",
                    "/tmp/fix.patch": manifest["patch"]["path"],
                    "/tests/reproduce.sh": "reproduce.sh", "/tests/trace-paths.sh": "trace-paths.sh",
                    "/tests/regression.sh": "scripts/regression.sh"}
    for image_path, local_path in image_inputs.items():
        actual_digest = run(prefix + ["sha256sum", image_path]).stdout.split()[0]
        assert actual_digest == digest(ROOT / local_path), f"Stale image input: {local_path}"
    environment = run(prefix + ["sh", "-c", "git --version; ghc --numeric-version; cabal --numeric-version; uname -m; sha256sum /opt/baseline/git-annex /opt/fixed/git-annex"]).stdout.splitlines()
    packages = run(prefix + ["dpkg-query", "-W", "-f=${Package}\t${Version}\n"]).stdout
    rows = []
    reproductions = []
    versions = {}
    for variant, expected in [("baseline", 1), ("fixed", 0)]:
        versions[variant] = run(prefix + [f"/opt/{variant}/git-annex", "version", "--raw"]).stdout.strip()
        result = run(prefix + ["sh", "-c", f"PATH=/opt/{variant}:$PATH sh /tests/reproduce.sh"], expected)
        reproductions.append({"variant": variant, "expected_exit": expected,
                              "observed_exit": result.returncode,
                              "discovery_errors": [line for line in result.stderr.splitlines()
                                                   if line.startswith("git-annex:") and "changeWorkingDirectory" in line]})
        result = run(prefix + ["sh", "/tests/regression.sh", variant])
        for line in result.stdout.splitlines():
            case, expected_status, observed = line.split("\t")
            assert expected_status == observed
            rows.append({"variant": variant, "case": case,
                         "expected": expected_status, "observed": observed, "passed": True})
    # Exercise upstream path properties too, without running the full integration suite.
    upstream = run(prefix + ["sh", "-c", "cd /tmp && PATH=/opt/fixed:$PATH git annex test --pattern '/prop_upFrom_basics/ || /prop_relPathDirToFileAbs/ || /prop_dirContains_regressionTest/'"])
    assert "All 4 tests passed" in upstream.stdout, upstream.stdout
    procedures = ["Containerfile.build", "reproduce.sh", "trace-paths.sh",
                  "scripts/regression.sh", "scripts/run-experiment.py", manifest["patch"]["path"]]
    result = {"schema_version": 1, "completed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "source": manifest, "procedure_sha256": {p: digest(ROOT / p) for p in procedures},
              "engine_version": run([args.engine, "--version"]).stdout.strip(),
              "image_id": run([args.engine, "image", "inspect", image, "--format", "{{.Id}}"]).stdout.strip(),
              "environment": environment, "binary_versions": versions,
              "installed_packages": dict(line.split("\t", 1) for line in packages.splitlines()),
              "reproductions": reproductions, "regressions": rows,
              "upstream_path_tests": {"exit_code": upstream.returncode,
                                      "summary": upstream.stdout.strip()},
              "scope": "Linux amd64; identical source-build toolchain and flags; local file operations and selected upstream path properties. Full upstream suite and other platforms not tested."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(rows)} regression observations, baseline reproduces, fixed passes")
    print(args.output)


if __name__ == "__main__":
    main()
