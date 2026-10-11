# Build attempt history

These attempts distinguish environment/setup failures from evidence about the patch.
No successful comparison is inferred from a failed or cancelled run.
Raw execution logs remain outside this repository.

| Attempt | Outcome |
| --- | --- |
| Local container build | Package installation exhausted the existing Docker disk before compilation. No cache was pruned. |
| [38161703671](https://github.com/leej3/git-annex-worktree-reproducer/actions/runs/38161703671) | Cancelled while preparing dependencies after a corrected build configuration superseded it. |
| [38161840352](https://github.com/leej3/git-annex-worktree-reproducer/actions/runs/38161840352) | Debian dependencies installed; Cabal's offline solver required an absent Hackage index. Changed to upstream direct `Setup` with installed libraries. |
| [38162969091](https://github.com/leej3/git-annex-worktree-reproducer/actions/runs/38162969091) | Direct configuration succeeded; `Setup build` rejected configure-only feature flags forwarded by Make. Separated configuration from compilation. The installed toolchain was cached. |

| [38163591880](https://github.com/leej3/git-annex-worktree-reproducer/actions/runs/38163591880) | Both binaries compiled. Baseline reproduced the linked-worktree failure and passed its controls. The regression helper overwrote the later fixture expectation; corrected its variable name. No completed comparison was emitted. |

| [38163958614](https://github.com/leej3/git-annex-worktree-reproducer/actions/runs/38163958614) | Completed comparison: baseline reproduces, patched reproducer succeeds, all 17 regression observations match expectations, four upstream path properties and six mandatory initialization/add checks pass. Selected results are preserved in `results/compiled-comparison.json`. |

Toolchain caching changes download cost, not the build recipe: Docker still checks the complete instructions, and the experiment verifies embedded source, patch, and procedure hashes.
