#!/bin/sh
# Run identical fixtures against either compiled binary.
set -eu
variant=${1:?baseline or fixed required}
case "$variant" in baseline|fixed) ;; *) exit 125 ;; esac
export PATH="/opt/$variant:$PATH"
root=$(mktemp -d /tmp/annex-regression-XXXXXX)
trap 'rm -rf "$root"' EXIT
probe() {
    name=$1 expected=$2
    if git annex info >"$root/$name.out" 2>"$root/$name.err"; then
        actual=success
    elif grep -q 'changeWorkingDirectory: does not exist' "$root/$name.err"; then
        actual=discovery_failure
    else
        cat "$root/$name.err" >&2
        actual=unexpected_failure
    fi
    printf '%s\t%s\t%s\n' "$name" "$expected" "$actual"
    [ "$actual" = "$expected" ]
}
smoke() {
    name=$1
    printf 'retained annex content\n' > payload.txt
    git annex add payload.txt >"$root/$name-add.out" 2>"$root/$name-add.err"
    git annex fsck payload.txt >"$root/$name-fsck.out" 2>"$root/$name-fsck.err"
    [ -L payload.txt ]
    [ "$(cat payload.txt)" = 'retained annex content' ]
    printf '%s\tsuccess\tsuccess\n' "$name"
}
cd "$root"
git init -q ordinary
git -C ordinary commit -qm initial --allow-empty
cd ordinary
git annex init fixture >/dev/null 2>"$root/init.err"
probe ordinary success
smoke ordinary_content
cd "$root"
git init -q source
git -C source commit -qm initial --allow-empty
git init -q main
git -C main -c protocol.file.allow=always submodule add -q "$root/source" sub
git -C main commit -qm submodule
cd main/sub
git annex init primary >/dev/null 2>"$root/primary-init.err"
probe primary_submodule success
cd "$root"
git -C main worktree add -qb linked ../linked
git -C linked -c protocol.file.allow=always submodule update --init -q
cd linked/sub
git annex init linked >/dev/null 2>"$root/linked-init.err"
expected=success
[ "$variant" = fixed ] || expected=discovery_failure
probe linked_submodule "$expected"
physical_gitdir=$(git rev-parse --absolute-git-dir)
(export GIT_DIR="$physical_gitdir"; probe physical_gitdir_control success)
if [ "$variant" = fixed ]; then smoke linked_submodule_content; fi
relative_worktree=$(git config --get core.worktree)
[ -L .git ]
rm .git
printf 'gitdir: %s\n' "$physical_gitdir" > .git
[ "$(git config --get core.worktree)" = "$relative_worktree" ]
probe gitdir_file_control success
cd "$root"
git init -q --separate-git-dir "$root/metadata" separate
git -C separate commit -qm initial --allow-empty
git -C separate config core.worktree ../separate
cd separate
git annex init separate >/dev/null 2>"$root/separate-init.err"
probe separate_gitdir_relative "$expected"
git config core.worktree "$root/separate"
probe separate_gitdir_absolute success
