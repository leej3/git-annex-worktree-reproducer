# git-annex linked-worktree submodule reproducer

This repository investigates a confirmed git-annex repository-discovery bug and contains a proposed fix.
It preserves the reproducer, source-level explanation, source snapshot, patch, build environment, executable controls, and comparison results.
The work follows the STAMPED principles in version 0.2.0.

## The failure

A submodule in a linked Git worktree stores its metadata under `main/.git/worktrees/linked/modules/sub`.
After `git annex init` converts `.git` into a symlink, git-annex simplifies the relative `core.worktree` path against that symlink's lexical location instead of its physical target.
Ordinary Git finds the correct worktree; `git annex info` tries `/../linked/sub` and fails.

See [the source trace](docs/source-trace.md), [the patch](patches/resolve-physical-gitdir.patch), and [the STAMPED evidence map](docs/stamped.md).

## Compile and repeat the comparison

Requirements: Python 3.9 or newer, a running Docker engine, network access to the pinned Debian image and package snapshot, and several GB of free container disk.
The experiment selects `linux/amd64`; ARM hosts require amd64 emulation.

```sh
python3 scripts/run-experiment.py
```

This builds the exact upstream source, preserves an unchanged binary, applies only the patch, and rebuilds a second binary with the same compiler and flags.
The upstream `Setup` build path uses only the libraries installed from Debian; no Hackage index or additional Cabal package downloads are required.
It then checks the original reproducer, regression fixtures, annex file-content operations, and selected upstream path properties.
Each fixture runs in a throwaway container.
Unexpected failures stop the procedure; results are written only after all required checks finish.

The unchanged binary must reproduce the discovery failure; the patched binary must succeed.
Regression fixtures cover ordinary repositories, primary submodules, linked-worktree submodules, explicit physical Git directories, restored gitdir files, and separate Git directories with relative and absolute worktree settings.
Content checks exercise `annex add`, locked-file reading, and `annex fsck`.

To reuse an existing build, use `--skip-build`.
Embedded source, patch, and procedure hashes are checked before it is accepted.
Use `--output PATH` to retain another comparison without replacing the checked-in observation.

## Earlier observations

`reproduce.sh` reports exit 0 for no reproduction, 1 for the confirmed target bug, and 125 for setup or verification failure.
`trace-paths.sh` isolates the symlink mechanism using the upstream standalone binary.
`containerfile.txt` preserves the earlier exploratory image definition, including the commented-out Debian 13 snapshot and the moving upstream download.
It is not the pinned source-build experiment; `Containerfile.build` is authoritative for that comparison.

```sh
docker build --platform linux/amd64 -f containerfile.txt -t annex-exploratory .
docker run --rm --platform linux/amd64 annex-exploratory
# Exit 1 is the expected confirmed-bug outcome.
docker run --rm -i --platform linux/amd64 annex-exploratory sh -s < trace-paths.sh
```

The bug was observed in Debian git-annex 10.20250416 and upstream standalone `10.20261006-g28ea958bf14a0ce0413b1ae8ac5c30b50e0c038e`.
The standalone run also emitted GHC ticker warnings under amd64 emulation, while its discovery controls completed as expected.

## Provenance and licensing

[sources/manifest.json](sources/manifest.json) pins upstream commit `28ea958bf14a0ce0413b1ae8ac5c30b50e0c038e`, the vendored source archive and patch SHA-256 values, the Debian image digest, and the package snapshot.
Build flags are in `Containerfile.build`.
Machine-readable comparison results record actual package versions, binary hashes, image identity, and procedure hashes.

New code and the proposed patch are AGPL-3.0-or-later.
Vendored upstream materials retain their original licenses and notices; see `sources/COPYRIGHT` and the archive's license files.
STAMPED reference materials are CC-BY-4.0 and retain attribution to the STAMPED principles project through the pinned reference lock.
The source excerpts in `evidence/source` are unchanged upstream files, not patched files.
No upstream acceptance or human review of the proposed fix is claimed.
