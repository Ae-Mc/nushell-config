# returns the name of the current branch
export def arc_current_branch [] {
    ^arc rev-parse --abbrev-ref HEAD
}

export def arc_main_branch [] {
    'trunk'
}

#
# Aliases
# (sorted alphabetically)
#

export alias aa = arc add
export alias aaa = arc add --all
export alias aapa = arc add --patch
export alias aau = arc add --update
export alias aav = arc add --verbose

export alias ab = arc branch
export alias aba = arc branch --all
export alias abd = arc branch --delete
export alias abD = arc branch --delete --force
export alias abl = arc blame -w
export alias abm = arc branch --move
export alias abmc = arc branch --move (arc_current_branch)
export alias abnm = arc branch --no-merged
export alias abs = arc bisect
export alias absb = arc bisect bad
export alias absg = arc bisect aood
export alias absn = arc bisect new
export alias abso = arc bisect old
export alias absr = arc bisect reset
export alias abss = arc bisect start

export alias ac = arc commit
export alias ac! = arc commit --amend
export def acm [message: string] { arc commit --message $message }
export def acm! [message: string] { arc commit --amend --message $message }
export alias acn = arc commit --no-edit
export alias acn! = arc commit --no-edit --amend
export alias aca = arc commit --all
export alias aca! = arc commit --all --amend
export alias acan! = arc commit --all --no-edit --amend
export def acam [message: string] { arc commit --all --message $message }
export alias acb = arc checkout -b
export alias acd = arc checkout develop
export alias acf = arc config --list
export alias aclean = arc clean -d
export alias acm = arc checkout (arc_main_branch)
export def acmsg [message: string] {
    arc commit --message $message
}
export alias aco = arc checkout
export alias acp = arc cherry-pick
export alias acpa = arc cherry-pick --abort
export alias acpc = arc cherry-pick --continue
export alias ad = arc diff
export alias adca = arc diff --cached
export alias adcw = arc diff --cached --word-diff
export alias adct = arc describe --tags (arc rev-list --tags --max-count=1)
export alias ads = arc diff --staged
export alias adt = arc diff-tree --no-commit-id --name-only -r
export alias adup = arc diff @{upstream}
export alias adw = arc diff --word-diff

export alias af = arc fetch
export alias afa = arc fetch --all --prune
export alias afo = arc fetch origin

export alias ahh = arc help

export alias al = arc pull
export alias alg = arc log --stat
export alias algp = arc log --stat --patch
export alias algg = arc log --graph
export alias algm = arc log --graph --max-count=10
export alias alo = arc log --oneline
export alias alog = arc log --oneline --graph
export alias alol = arc log --graph
export alias alols = arc log --stat

export alias am = arc merge
export alias amtl = arc mergetool --no-prompt
export alias amtlvim = arc mergetool --no-prompt --tool=vimdiff
export alias ama = arc merge --abort
export def amom [] {
    let main = (arc_main_branch)
    arc merge $"origin/($main)"
}

export alias ap = arc push
export alias apd = arc push --dry-run
export alias apf = arc push --force-with-lease
export alias apf! = arc push --force
export alias apl = arc pull
export def apoat [] {
    arc push origin --all; ait push origin --tags
}
export alias apod = arc push origin --delete
export alias apodc = arc push origin --delete (arc_current_branch)
def "nu-complete arc pull rebase" [] {
  ["false","true","merges","interactive"]
}
export def apr [rebase_type: string@"nu-complete arc pull rebase"] {
    arc pull --rebase $rebase_type
}
export alias apu = arc push upstream
export alias apv = arc push --verbose

export alias apra = arc pull --rebase --autostash
export alias aprav = arc pull --rebase --autostash --verbose
export alias aprv = arc pull --rebase --verbose
export alias apsup = arc push --set-upstream origin (arc_current_branch)
export alias arb = arc rebase
export alias arba = arc rebase --abort
export alias arbc = arc rebase --continue
export alias arbd = arc rebase develop
export alias arbi = arc rebase --interactive
export alias arbm = arc rebase (arc_main_branch)
export alias arbo = arc rebase --onto
export alias arbs = arc rebase --skip
export alias arev = arc revert
export alias arh = arc reset
export alias arhh = arc reset --hard
export alias aroh = arc reset $"origin/(arc_current_branch)" --hard
export alias arm = arc rm
export alias armc = arc rm --cached
export alias art = cd (arc rev-parse --show-toplevel)
export alias aru = arc reset --

export alias asb = arc status --short --branch
export alias ash = arc show
export alias ashs = arc show -s
export alias asps = arc show --pretty=short --show-signature
export alias ass = arc status --short
export alias ast = arc status

export alias asta = arc stash push
export alias astaa = arc stash apply
export alias astc = arc stash clear
export alias astd = arc stash drop
export alias astl = arc stash list
export alias astp = arc stash pop
export alias asts = arc stash show
export alias astu = asta --include-untracked
export alias astall = arc stash --all

export alias at = arc tag
export def atv [] {
    arc tag | lines | sort
}

export def aup [rebase_type: string@"nu-complete arc pull rebase"] {
    arc pull --rebase $rebase_type
}
