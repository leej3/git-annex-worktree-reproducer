# Source-level explanation

The source files in `evidence/source` were extracted from upstream commit `28ea958bf14a0ce0413b1ae8ac5c30b50e0c038e`, matching the tested standalone binary.
Their original paths and SHA-256 values are in `evidence/source-provenance.json`.
The complete source snapshot is included in `sources/`.

## How the failing layout arises

`Annex.Init.initialize` calls `fixupUnusualReposAfterInit` (`Init.hs`, line 182).
That helper invokes `Annex.Fixup.fixupUnusualRepos` (lines 519–522).

`needsSubmoduleFixup` (`Fixup.hs`, lines 143–146) recognizes paths containing `.git/modules`.
The linked-worktree submodule path contains `.git/worktrees/linked/modules`, so this test misses it.
The generic branch at lines 95–104 converts `.git` to a symlink without the `unsetcoreworktree` action in the submodule branch at lines 87–94.

The trace script verifies that `.git` was a pointer file before initialization, becomes a symlink afterward, and retains exactly the same relative setting:

```text
.git -> ../../main/.git/worktrees/linked/modules/sub
core.worktree = ../../../../../../linked/sub
```

## Where startup computes the wrong path

1. `Git.Construct.checkForRepo` (`Construct.hs`, lines 241–260) sees `.git/config` through the symlink and produces `LocalUnknown`.
2. `Git.Config.updateLocation` (`Config.hs`, lines 153–174) constructs a local repository whose Git directory is `worktree/.git`.
3. `Git.Config.updateLocation'` (lines 179–189) reads `core.worktree` and computes `absPathFrom top d`, with `top <- absPath (gitdir l)`.
4. `absPath` and `absPathFrom` (`AbsRel.hs`, lines 37–54) use `simplifyPath`.
   The simplifier (`Path.hs`, lines 61–75) removes `directory/..` textually, without following filesystem symlinks.
5. `Git.CurrentRepo.get` (`CurrentRepo.hs`, lines 42–51) attempts `setCurrentDirectory` with `/../linked/sub`, producing the observed error.

Physical traversal starts from the deeper metadata directory and correctly reaches the submodule.
Textual simplification starts from `linked/sub/.git` and runs past the filesystem root.

## Intervention evidence

`trace-paths.sh` verifies that ordinary Git and `cd -P` reach the correct worktree.
Normal `git annex info` and `GIT_DIR="$PWD/.git" git annex info` both fail with the same incorrect path.
Supplying only the physical `GIT_DIR` succeeds.
Replacing only `.git` with a pointer file also succeeds, with unchanged relative `core.worktree`.
These controls isolate symlink representation from repository content and configuration changes.

## Proposed correction

The patch changes `top <- absPath (gitdir l)` to `top <- canonicalizePath (gitdir l)`.
That resolves the physical Git directory before relative worktree arithmetic.
It corrects the discovery mechanism and also applies to separate Git directories with the same symlink layout.

The patch intentionally leaves the layout-sensitive submodule detector unchanged.
That detector explains how the triggering layout arises, but canonicalizing the Git directory fixes its subsequent discovery failure while preserving the existing `core.worktree` configuration.

The source trace and original interventions did not compile a modified binary.
The separate compiled comparison tests the patch against an unchanged binary built from the same source and environment.
Its results define the supported scope; this is not a claim about every platform or all git-annex functionality.
