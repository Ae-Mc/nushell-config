# returns the name of the current branch
export def arc_current_branch [] {
    ^arc info --json | from json | get branch
}

# returns the name of the remote branch tracked by the current one,
# falls back to the local branch name when nothing was pushed yet
export def arc_current_remote_branch [] {
    let info = ^arc info --json | from json
    $info | get --optional remote | default $info.branch
}

export def arc_main_branch [] {
    'trunk'
}

# arc keeps every remote ref under a single namespace, there is no `origin`
export def arc_remote [] {
    'arcadia'
}

def "nu-complete arc pull rebase" [] {
  ["false", "true", "interactive"]
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
export alias abD = arc branch -D
export alias abl = arc blame -w
export alias abm = arc branch --move
export alias abmc = arc branch --move (arc_current_branch)
export alias abmg = arc branch --merged
export alias abs = arc bisect
export alias absb = arc bisect bad
export alias absg = arc bisect good
export alias absr = arc bisect reset
export alias abss = arc bisect start

export alias ac = arc commit
export alias ac! = arc commit --amend
export alias aca = arc commit --all
export alias aca! = arc commit --all --amend
export def acam [message: string] { arc commit --all --message $message }
export alias acan! = arc commit --all --no-edit --amend
export alias acb = arc checkout -b
export alias acf = arc config --list
export alias aclean = arc clean -d
export alias acm = arc checkout (arc_main_branch)
export def acmsg [message: string] { arc commit --message $message }
export def acmsg! [message: string] { arc commit --amend --message $message }
export alias acn = arc commit --no-edit
export alias acn! = arc commit --no-edit --amend
export alias aco = arc checkout
export alias acp = arc cherry-pick
export alias acpa = arc cherry-pick --abort
export alias acpc = arc cherry-pick --continue
export alias acps = arc cherry-pick --skip

export alias ad = arc diff
export alias adca = arc diff --cached
export alias ads = arc diff --staged
export alias adw = arc diff --ignore-all-space

export alias af = arc fetch
export alias afm = arc fetch --my

export alias ahh = arc help

export alias al = arc pull
export alias alg = arc log --stat
export alias algp = arc log --stat --patch
export alias algg = arc log --graph
export alias algm = arc log --graph --max-count=10
export alias alm = arc pull (arc_main_branch)
export alias alo = arc log --oneline
export alias alog = arc log --oneline --graph

export alias amtl = arc mergetool --no-prompt
export alias amtlvim = arc mergetool --no-prompt --tool=vimdiff

export alias ap = arc push
export alias apf = arc push --force
export alias apod = arc push --delete
export alias apodc = arc push --delete (arc_current_branch)
export alias app = arc push --publish
export def apr [rebase_type: string@"nu-complete arc pull rebase" = "true"] {
    arc pull $"--rebase=($rebase_type)"
}
export alias apsup = arc push --set-upstream (arc_current_branch)

export alias arb = arc rebase
export alias arba = arc rebase --abort
export alias arbc = arc rebase --continue
export alias arbi = arc rebase --interactive
export alias arbm = arc rebase (arc_main_branch)
export alias arbo = arc rebase --onto
export alias arbs = arc rebase --skip
export alias arev = arc revert
export alias arh = arc reset
export alias arhh = arc reset --hard
export def aroh [] {
    arc reset --hard $"(arc_remote)/(arc_current_remote_branch)"
}
export alias arm = arc rm
export alias armc = arc rm --cached
export alias art = cd (arc root)

export alias asb = arc status --short --branch
export alias ash = arc show
export alias ashs = arc show --quiet
export alias ass = arc status --short
export alias ast = arc status

export alias asta = arc stash push
export alias astaa = arc stash apply
export alias astall = arc stash push --all
export alias astc = arc stash clear
export alias astd = arc stash drop
export alias astl = arc stash list
export alias astp = arc stash pop
export alias asts = arc stash show
export alias astu = arc stash push --include-untracked

export alias at = arc tag
export def atv [] {
    arc tag --list | lines | sort
}

export alias aup = arc up
