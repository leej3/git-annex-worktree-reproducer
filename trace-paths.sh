#!/bin/sh
set -eu
workdir=$(mktemp -d "${TMPDIR:-/tmp}/git-annex-worktree-XXXXXX")
cd "$workdir"
workdir=$(pwd -P)
git init -q source
git -C source commit -qm initial --allow-empty
git init -q main
git -C main -c protocol.file.allow=always submodule add -q "$workdir/source" sub
git -C main commit -qm submodule
git -C main worktree add -qb linked ../linked
git -C linked -c protocol.file.allow=always submodule update --init -q
cd linked/sub
[ -f .git ] && [ ! -L .git ]
original_worktree=$(git config --get core.worktree)
printf 'BEFORE init .git: '; cat .git
printf 'BEFORE init core.worktree: %s\n' "$original_worktree"
git annex init repro
[ -L .git ]
[ "$(git config --get core.worktree)" = "$original_worktree" ]
echo 'AFTER init: .git is a symlink; relative core.worktree is unchanged'


printf 'annex version: '; git annex version --raw; echo
printf 'cwd: '; pwd -P
printf '.git symlink: '; readlink .git
printf 'core.worktree: '; git config --get core.worktree
physical_gitdir=$(git rev-parse --absolute-git-dir)
printf 'physical gitdir: %s\n' "$physical_gitdir"
printf 'Git worktree: '; git rev-parse --show-toplevel
printf 'lexical base plus core.worktree: %s/.git/%s\n' "$PWD" "$(git config --get core.worktree)"
printf 'Filesystem resolution of symlink plus core.worktree: '
(cd -P "$PWD/.git/$original_worktree" && pwd -P)
if git annex info >normal.out 2>normal.err; then echo UNEXPECTED_NORMAL_PASS; exit 125; fi
grep 'changeWorkingDirectory' normal.err
if GIT_DIR="$PWD/.git" git annex info >lexical.out 2>lexical.err; then echo UNEXPECTED_SYMLINK_PASS; exit 125; fi
grep 'changeWorkingDirectory' lexical.err
GIT_DIR="$physical_gitdir" git annex info >physical.out 2>physical.err
echo 'PASS: physical GIT_DIR alone fixes failure'
# Convert only the generated symlink back to Git's original gitdir-file form.
# Repository metadata and core.worktree stay unchanged.
relative_worktree=$(git config --get core.worktree)
rm .git
printf 'gitdir: %s\n' "$physical_gitdir" > .git
[ "$(git config --get core.worktree)" = "$relative_worktree" ]
git annex info >gitfile.out 2>gitfile.err
echo 'PASS: gitdir file fixes failure with unchanged relative core.worktree'
