#!/bin/sh
PS4='> '
set -eux
# 0 = pass, 1 = confirmed bug, 125 = setup/verification failure.
result=125
trap 'if [ "$result" -eq 125 ]; then echo "INCONCLUSIVE: setup or verification failed" >&2; fi; exit "$result"' 0

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
git annex init repro

work_tree=$(git rev-parse --show-toplevel)
[ "$work_tree" = "$workdir/linked/sub" ]
git status --porcelain >/dev/null
printf 'Valid worktree (ordinary Git succeeds): %s\n' "$work_tree"
if git annex info >actual.stdout 2>actual.stderr; then
    echo 'PASS: target bug not reproduced'
    result=0; exit 0
fi
cat actual.stderr >&2
grep -q 'changeWorkingDirectory: does not exist' actual.stderr
GIT_DIR=$(git rev-parse --absolute-git-dir) \
GIT_WORK_TREE="$work_tree" git annex info >/dev/null
echo 'CONFIRMED BUG: Annex discovery fails; ordinary Git and the absolute-path workaround succeed.'
result=1
exit 1
