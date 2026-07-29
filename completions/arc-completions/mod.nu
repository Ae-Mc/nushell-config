# nu-version: 0.102.0

module arc-completion-utils {
  # Flags which may be passed to `arc` itself, before a subcommand
  export const ARC_SKIPABLE_FLAGS = ['-v', '--version', '-h', '--help', '--svnrevision']

  # Helper function to append token if non-empty
  def append-non-empty [token: string]: list<string> -> list<string> {
    if ($token | is-empty) { $in } else { $in | append $token }
  }

  # Split a string to list of args, taking quotes into account.
  # Code is copied and modified from https://github.com/nushell/nushell/issues/14582#issuecomment-2542596272
  export def args-split []: string -> list<string> {
    # Define our states
    const STATE_NORMAL = 0
    const STATE_IN_SINGLE_QUOTE = 1
    const STATE_IN_DOUBLE_QUOTE = 2
    const STATE_ESCAPE = 3
    const WHITESPACES = [" " "\t" "\n" "\r"]

    # Initialize variables
    mut state = $STATE_NORMAL
    mut current_token = ""
    mut result: list<string> = []
    mut prev_state = $STATE_NORMAL

    # Process each character
    for char in ($in | split chars) {
      if $state == $STATE_ESCAPE {
        # Handle escaped character
        $current_token = $current_token + $char
        $state = $prev_state
      } else if $char == '\' {
        # Enter escape state
        $prev_state = $state
        $state = $STATE_ESCAPE
      } else if $state == $STATE_NORMAL {
        if $char == "'" {
          $state = $STATE_IN_SINGLE_QUOTE
        } else if $char == '"' {
          $state = $STATE_IN_DOUBLE_QUOTE
        } else if ($char in $WHITESPACES) {
          # Whitespace in normal state means token boundary
          $result = $result | append-non-empty $current_token
          $current_token = ""
        } else {
          $current_token = $current_token + $char
        }
      } else if $state == $STATE_IN_SINGLE_QUOTE {
        if $char == "'" {
          $state = $STATE_NORMAL
        } else {
          $current_token = $current_token + $char
        }
      } else if $state == $STATE_IN_DOUBLE_QUOTE {
        if $char == '"' {
          $state = $STATE_NORMAL
        } else {
          $current_token = $current_token + $char
        }
      }
    }
    # Handle the last token
    $result = $result | append-non-empty $current_token
    # Return the result
    $result
  }

  # Flat list of the files reported by `arc status`, annotated with the group
  # they belong to: `staged`, `changed`, `unmerged` or `untracked`
  export def get-status-entries [] {
    ^arc status --json -uall
    | from json
    | get status
    | transpose group entries
    # `branch_info` and friends are records, only file groups are lists
    | where ($it.entries | describe) =~ '^(list|table)'
    | each { |group| $group.entries | insert group $group.group }
    | flatten
    | select path status group
  }

  # Get files with local modifications, they can be restored by `arc checkout -- <file>`
  export def get-changed-files []: nothing -> list<string> {
    get-status-entries | where group in [changed unmerged] | get path
  }

  # Get files which can be retrieved from a branch/commit by `arc checkout <tree-ish> <file>`
  export def get-checkoutable-files []: nothing -> list<string> {
    get-status-entries | where group in [staged changed unmerged] | get path
  }

  # Get files which can be unstaged by `arc reset <file>`
  export def get-staged-files []: nothing -> list<string> {
    get-status-entries | where group == staged | get path
  }

  export def get-local-branches []: nothing -> list<record<value: string, description: string>> {
    ^arc branch --list --json
    | from json
    | where ($it.current? != true)
    | get name
    | wrap value
    | insert description "local branch"
  }

  # Remote branches are stored under the single `arcadia/` namespace, arc has no `origin`
  export def get-remote-branches []: nothing -> list<record<value: string, description: string>> {
    ^arc branch --all --json
    | from json
    | where ($it.local? != true)
    | get name
    | wrap value
    | insert description "remote branch"
  }
}

use arc-completion-utils *

def "nu-complete arc branches" [] {
  get-local-branches | append (get-remote-branches)
}

# Branch names as `arc fetch` expects them, i.e. without the `arcadia/` prefix
def "nu-complete arc fetchable branches" [] {
  get-remote-branches
  | update value { str replace --regex '^arcadia/' '' }
  | update description "remote branch"
}

# Yield all existing commits in descending chronological order.
def "nu-complete arc commits all" [] {
  ^arc log --oneline -n 400 | lines | parse "{value} {description}"
}

# Yield local branches like `trunk`, `feature/typo_fix`
def "nu-complete arc local branches" [] {
  get-local-branches
}

def "nu-complete arc checkout" [context: string, position?:int] {
  let preceding = $context | str substring ..$position
  # See what user typed before, like 'arc checkout a-branch a-path'.
  # We exclude some flags from previous tokens, to detect if  a branch name has been used as the first argument.
  # FIXME: This method is still naive, though.
  let prev_tokens = $preceding | str trim | args-split | where ($it not-in $ARC_SKIPABLE_FLAGS)
  # In these scenarios, we suggest only file paths, not branch:
  # - After '--'
  # - First arg is a branch
  # If before '--' is just 'arc checkout' (or its alias), we suggest "dirty" files only (user is about to reset file).
  if $prev_tokens.2? == '--' {
    return (get-changed-files)
  }
  if '--' in $prev_tokens {
    return (get-checkoutable-files)
  }
  # Already typed first argument.
  if ($prev_tokens | length) > 2 and $preceding ends-with ' ' {
    return (get-checkoutable-files)
  }
  # The first argument can be local branches, remote branches, files and commits
  # Get local and remote branches
  let branches = nu-complete arc branches
  let files = (get-checkoutable-files) | wrap value | insert description 'File' | insert style green
  let commits = ^arc log -n 100 --oneline
    | lines
    | split column -n 2 ' ' value description
    | upsert description {|x| $'Commit, ($x.value) ($x.description)' }
    | insert style 'light_cyan_dimmed'
  {
    options: {
        case_sensitive: false,
        completion_algorithm: prefix,
        sort: false,
    },
    completions: [...$branches, ...$files, ...$commits]
  }
}

# Arguments to `arc reset [BRANCH] [PATH]...`
def "nu-complete arc reset" [] {
  nu-complete arc refs
  | append ((get-staged-files) | wrap value | insert description "staged file")
}

# Arguments to `arc rebase [UPSTREAM] [BRANCH]` and `arc rebase --onto <newbase>`
def "nu-complete arc rebase" [] {
  nu-complete arc branches
  | append (nu-complete arc commits all)
}

def "nu-complete arc stash-list" [] {
  ^arc stash list | lines | parse -r '\w* (?P<value>[^:]*): (?P<description>.*)'
}

def "nu-complete arc tags" [] {
  ^arc tag --list | lines | wrap value | insert description "tag"
}

def "nu-complete arc files" [] {
  get-status-entries | select path status | rename value description
}

def "nu-complete arc built-in-refs" [] {
  [
    { value: HEAD, description: "current commit" }
    { value: ORIG_HEAD, description: "commit before the last drastic operation" }
  ]
}

def "nu-complete arc refs" [] {
  nu-complete arc branches
  | append (nu-complete arc tags)
  | append (nu-complete arc built-in-refs)
}

def "nu-complete arc files-or-refs" [] {
  nu-complete arc refs
  | append (nu-complete arc files | where description == modified)
}

def "nu-complete arc subcommands" [] {
  ^arc list-commands | from json | select command description? | rename value | where not ($it.value starts-with '--')
}

def "nu-complete arc add" [] {
  nu-complete arc files
}

def "nu-complete arc pull rebase" [] {
  ["false", "true", "interactive"]
}

# Values accepted by `-X`, the merge strategy option
def "nu-complete arc strategy options" [] {
  ['ours', 'theirs']
}

def "nu-complete arc empty commits" [] {
  ['drop', 'keep']
}

def "nu-complete arc color" [] {
  ['auto', 'always', 'never']
}

def "nu-complete arc untracked mode" [] {
  ['all', 'no', 'normal']
}

def "nu-complete arc merge tools" [] {
  ^arc mergetool --tool-help | lines | where $it =~ '^\s{4,}\S+$' | str trim
}

def "nu-complete arc diff tools" [] {
  ^arc difftool --tool-help | lines | where $it =~ '^\s{4,}\S+$' | str trim
}

# Outgoing pull requests, `arc pr` addresses them either by id or by branch
def "nu-complete arc pull-requests" [] {
  ^arc pr list --json --limit 30
  | from json --objects
  | select id summary
  | rename value description
  | update value { into string }
}

def "nu-complete arc pr targets" [] {
  nu-complete arc pull-requests | append (get-local-branches)
}

def "nu-complete arc pr statuses" [] {
  ['all', 'open', 'merged', 'discarded']
}

def "nu-complete arc pr sort" [] {
  ['status', 'date', 'summary', 'id']
}

def "nu-complete arc config keys" [] {
  ^arc config --list --name-only | lines
}


# Check out arc branches and files
export extern "arc checkout" [
  ...targets: string@"nu-complete arc checkout"   # name of the branch, commit or files to checkout
  -b: string                                      # create and checkout a new branch
  --force(-f)                                     # force checkout (throw away local modifications)
  --quiet(-q)                                     # suppress progress reporting
  --no-track                                      # do not set up upstream configuration
  --ours                                          # checkout our version for unmerged paths
  --upstream                                      # same as --ours
  --theirs                                        # checkout their version for unmerged paths
  --branch                                        # same as --theirs
  --resolve-ours                                  # resolve conflicts with ours as favor when checking out paths from the index
  --resolve-upstream                              # same as --resolve-ours
  --resolve-theirs                                # resolve conflicts with theirs as favor when checking out paths from the index
  --resolve-branch                                # same as --resolve-theirs
]

# Reset current HEAD to the specified state
export extern "arc reset" [
  ...targets: string@"nu-complete arc reset"      # name of commit, branch, or files to reset
  --hard                                          # reset HEAD, index and working tree
  --mixed                                         # reset HEAD and index (default)
  --soft                                          # reset only HEAD
  --quiet(-q)                                     # be quiet, only report errors
  --force(-f)                                     # reset even if prohibited by config
]

# Download refs from remote repository
export extern "arc fetch" [
  ...branches: string@"nu-complete arc fetchable branches" # branches to fetch, a trailing '/' fetches every branch with such prefix
  --my                                                    # also fetch all current user branches
  --verbose                                               # print updated refs to stdout
]

# Update remote refs along with associated objects
export extern "arc push" [
  ...refs: string@"nu-complete arc local branches"   # the branch to push
  --delete(-d): string@"nu-complete arc local branches" # delete branch on server
  --set-upstream(-u): string                         # add upstream (tracking) reference
  --all                                              # push all refs
  --force(-f)                                        # force updates
  --no-verify                                        # disable the pre-push hook
  --wait                                             # wait until PR is updated
  --publish(-p)                                      # publish the latest diff-set in PR
  --quiet(-q)                                        # suppress diff output
]

# Fetch from remote repository and integrate with a local branch
export extern "arc pull" [
  branch?: string@"nu-complete arc local branches"       # name of local branch (default: current)
  --rebase(-r): any@"nu-complete arc pull rebase"        # rebase if branches diverge
  --ff-only                                              # abort if fast-forward is not possible
  --force(-f)                                            # force checkout (throw away local modifications)
  --quiet(-q)                                            # do not print names of files removed
]

# Update current PR to the freshest upstream (usually trunk)
export extern "arc up" [
  --to: string@"nu-complete arc refs" # update to given branch or commit instead of trunk
  --abort                             # abort the current conflict resolution process
  --no-squash                         # (not supported yet) don't squash commits
]

# Apply the changes introduced by some existing commits
export extern "arc cherry-pick" [
  ...commits: string@"nu-complete arc commits all"     # rev, or rev..rev, or rev...rev
  --edit(-e)                                           # edit the commit message
  --no-commit(-n)                                      # don't automatically commit
  --mainline(-m): int                                  # parent number
  -X: string@"nu-complete arc strategy options"        # pass the argument through to the merge strategy
  -x                                                   # append commit name
  --allow-empty-message                                # allow commits with empty messages
  --allow-empty                                        # commit even if the result has the same tree as its parent
  --continue                                           # resume cherry-pick sequence
  --abort                                              # abort and check out the original branch
  --skip                                               # skip current commit and continue
  --force(-f)                                          # cherry-pick even if prohibited by config
  --dont-resolve-moves                                 # do not resolve moves
  --quiet(-q)                                          # be quiet
]

# Forward-port local commits to the updated upstream head
export extern "arc rebase" [
  upstream?: string@"nu-complete arc rebase"  # branch name or commit to rebase onto
  branch?: string@"nu-complete arc rebase"    # branch to rebase, current one by default
  --onto: string@"nu-complete arc rebase"     # rebase onto given branch instead of upstream
  --interactive(-i)                           # let the user edit the list of commits to rebase
  --autosquash                                # respect squash!/fixup! commits made by `arc commit --squash/--fixup`
  --continue                                  # restart the rebasing process after having resolved a merge conflict
  --abort                                     # abort and check out the original branch
  --skip                                      # restart the rebasing process by skipping the current patch
  --checkout-conflicts                        # checkout on branch only if rebase conflict occurred
  --virtual                                   # abort if rebase conflict occurred, no checkout on branch
  --empty: string@"nu-complete arc empty commits" # whether to keep commits which do not change anything
  -X: string@"nu-complete arc strategy options"   # pass the argument through to the merge strategy
  --all-parents                               # consider all parents instead of only the first one
  --include-merges                            # include merge commits into rebase
  --dont-resolve-moves                        # do not resolve moves during this rebase
  --force(-f)                                 # rebase even if prohibited by config
  --quiet(-q)                                 # be quiet
]

# Show what revision and author last modified each line of a file
export extern "arc blame" [
  commit_or_path: string@"nu-complete arc files-or-refs" # commit to blame at, or the file itself
  path?: string                                          # file to blame
  --revisions(-r)                                        # show revision numbers
  -s                                                     # suppress author name and timestamp
  --json                                                 # output in json format
  -w                                                     # ignore whitespace when comparing lines
  --ignore-rev: string@"nu-complete arc commits all"     # ignore changes made by the provided revision
  --ignore-revs-file: string                             # ignore changes made by revisions listed in provided file, .arc-blame-ignore-revs by default
  --show-pulls                                           # also consider merge commits that are TREESAME to a later parent only
  -L: string                                             # annotate only the specified lines, <start>,<end>
  --first-parent                                         # walk through first parent only
  --full-topo                                            # full topology history walk
]

# Manage branches: list, create, delete, etc
export extern "arc branch" [
  branch?: string@"nu-complete arc local branches"    # branch name
  start?: string@"nu-complete arc refs"               # start point for a new branch, new name for move
  ...args: string@"nu-complete arc local branches"    # branch names for delete operation
  --list(-l)                                          # list branch names
  --all(-a)                                           # list both remote-tracking and local branches
  --delete(-d)                                        # delete branch if all its commits are pushed to remote
  -D                                                  # force delete branch
  --move(-m)                                          # move/rename branch
  -M                                                  # shortcut for --move --force
  --force(-f)                                         # force creation, move/rename, deletion
  --set-upstream-to(-u): string@"nu-complete arc branches" # change the upstream info
  --unset-upstream                                    # unset the upstream info
  --merged                                            # print only branches that are merged
  --points-at: string@"nu-complete arc refs"          # print only branches of the object
  --desc: string                                      # branch description
  --json                                              # output in json format
  --verbose(-v)                                       # show hash and subject, give twice for upstream branch
  --quiet(-q)                                         # suppress informational messages
]

# Show changes between commits, commit and working tree, etc
export extern "arc diff" [
  rev1_or_file?: string@"nu-complete arc files-or-refs"
  rev2?: string@"nu-complete arc refs"
  ...paths: string@"nu-complete arc files"
  --cached                                             # calculate diff with index
  --staged                                             # same as --cached
  --base(-B)                                           # show changes between merge-base(trunk, HEAD) and HEAD
  --unified(-U): int                                   # generate diffs with <n> lines of context
  --name-only                                          # show only names of changed files
  --name-status                                        # show only names and status of changed files
  --stat                                               # show diffstat
  --json                                               # output in json format
  --patience                                           # generate a diff using the 'patience diff' algorithm
  --no-patience                                        # do not use the 'patience diff' algorithm
  --ignore-all-space(-w)                               # ignore whitespace when comparing lines
  --ignore-space-change(-b)                            # ignore changes in amount of whitespace
  --ignore-space-at-eol                                # ignore changes in whitespace at EOL
  --reverse(-R)                                        # (experimental) reverse diff sides
  --resolve-moves: string                              # (experimental) resolve and show path copies & moves
  --relative: string                                   # exclude changes outside <path> and show pathnames relative to it
  --binary                                             # output a binary diff in 'GIT binary patch' format
  --svn                                                # use svn compatible diff format
  --git                                                # use git compatible diff format
  --color: string@"nu-complete arc color"              # set color mode
  --no-color                                           # set color mode never
]

# Record changes to the repository
export extern "arc commit" [
  ...pathspec: string@"nu-complete arc files"         # commit files matching pathspec
  --message(-m): string                               # commit message
  --file(-F): string                                  # read message from file
  --edit(-e)                                          # further edit message taken from file with -F, command line with -m
  --no-edit                                           # use the selected commit message without launching an editor
  --all(-a)                                           # commit all changed files
  --amend                                             # amend previous commit
  --fixup: string@"nu-complete arc commits all"       # mark this commit as a fixup of COMMIT for `arc rebase --autosquash`
  --squash: string@"nu-complete arc commits all"      # squash this commit with COMMIT in `arc rebase --autosquash`
  --reset-author                                      # discard original author when used with --amend
  --allow-empty-message                               # allow to create a commit with an empty commit message
  --dry-run                                           # show what would be committed
  --no-verify(-n)                                     # bypass pre-commit hooks
  --skip-hook: string                                 # skip specific pre-commit hook
  --force(-f)                                         # commit even if prohibited by config
]

# Show commit logs
export extern "arc log" [
  # Ideally we'd allow completion of revisions here, but that would make completion of filenames not work.
  --max-count(-n): int                                # number of commits to output
  --oneline                                           # print commit info in one line
  --graph                                             # show the graph
  --stat                                              # show the diffstat
  --patch(-p)                                         # generate patch
  --unified(-U): int                                  # generate diffs with <n> lines of context
  --name-only                                         # show only names of changed files
  --name-status                                       # show only names and status of changed files
  --author: string                                    # show commits of specified author
  --grep: string                                      # show commits with message matching specified value
  --search(-S): string                                # show commits which has specified string in changes
  --after: string                                     # show commits recent than a specific date
  --before: string                                    # show commits older than a specific date
  --follow                                            # continue listing the history of a file beyond implicit renames
  --first-parent                                      # walk through first parent only
  --full-topo                                         # full topology history walk
  --show-pulls                                        # include merge commits that are TREESAME to a later parent only
  --no-walk                                           # only show the given commits
  --no-decorate                                       # do not print branch info if any
  --attrs                                             # show attributes
  --format: string                                    # (experimental) pretty-formats commits according to a pattern
  --pretty: string                                    # same as --format
  --relative: string                                  # exclude changes outside <path> and show pathnames relative to it
  --resolve-moves                                     # (experimental) resolve and show path copies & moves
  --json                                              # output in json format
  --json-lines                                        # output in json format as received
  --color: string@"nu-complete arc color"             # set color mode
  --no-color                                          # set color mode never
]

# Show reflogs
export extern "arc reflog show" [
  ref?: string@"nu-complete arc refs"                 # reference to show the log of, HEAD by default
  --max-count(-n): int                                # number of commits to output
  --stat                                              # show the diffstat
  --author: string                                    # show commits of specified author
  --grep: string                                      # show commits with message matching specified value
  --after: string                                     # show commits recent than a specific date
  --before: string                                    # show commits older than a specific date
  --no-decorate                                       # do not print branch info if any
  --json                                              # output in json lines format
]

# Add file contents to the index
export extern "arc add" [
  ...file: string@"nu-complete arc add"               # file to add
  --all(-A)                                           # add changes from all tracked and untracked files
  --update(-u)                                        # update tracked files
  --patch(-p)                                         # interactively choose hunks of patch
  --force(-f)                                         # add even ignored files
  --dry-run(-n)                                       # don't actually add the file(s), just show what would happen
  --ignore-removal                                    # ignore paths removed in the working tree
  --chmod: string                                     # (+x|-x) override executable flag only in stage
  -F: string                                          # add content of file to index, to stage partial changes
  --verbose(-v)                                       # be verbose
]

# Remove files from the working tree and from the index
export extern "arc rm" [
  ...paths: string@"nu-complete arc files"             # files to remove
  -r                                                   # allow recursive removal
  --cached                                             # only remove from the index
  --force(-f)                                          # override the up-to-date check
  --dry-run(-n)                                        # dry run
  --ignore-unmatch                                     # exit with a zero status even if nothing matched
  --quiet(-q)                                          # do not list removed files
]

# Show the working tree status
export extern "arc status" [
  ...paths: string                                    # limit the status to the given paths
  --short(-s)                                         # show status concisely
  --branch(-b)                                        # show branch information
  -u: string@"nu-complete arc untracked mode"         # show untracked files
  --ignored                                           # show ignored files
  --json                                              # output in json format
  --no-ahead-behind                                   # do not display detailed ahead/behind counts
  --no-sync-status                                    # do not display status of current synchronization process
  --no-bisect-status                                  # do not display status of current bisection
]

# Stash changes, list or apply existing stashes.
# Note that stashes are kept in a stack at a special ref `stash`
export extern "arc stash" []

# Create a stash entry and push it onto stack
export extern "arc stash push" [
  ...paths: string@"nu-complete arc files"            # limit the stash to the given paths
  --message(-m): string                               # stash description
  --include-untracked(-u)                             # stash untracked files too
  --all(-a)                                           # stash untracked and ignored files too
  --keep-index(-k)                                    # keep the staged changes in the index
  --no-cleanup                                        # do not revert modifications
  --quiet(-q)                                         # be quiet
]

# Apply stash entry and remove it from stack
export extern "arc stash pop" [
  stash?: string@"nu-complete arc stash-list"          # stash to pop
  --index                                              # restore index state
  --quiet(-q)                                          # be quiet
]

# Apply a stash entry, not removing it from stack
export extern "arc stash apply" [
  stash?: string@"nu-complete arc stash-list"          # stash to apply
  --index                                              # restore index state
  --quiet(-q)                                          # be quiet
]

# List current stash stack
export extern "arc stash list" [
  --grep: string                                      # show stashes with message matching specified value
  --ignore-case(-i)                                   # ignore case differences between the patterns and the files
  --json                                              # output in json format
]

# Show diff between the stash entry and the commit it was created from
export extern "arc stash show" [
  stash?: string@"nu-complete arc stash-list"
  --unified(-U): int                                  # generate diffs with <n> lines of context
  --include-untracked(-u)                             # add untracked files to show
  --only-untracked                                    # add only untracked files to show
  --name-only                                         # show only names of changed files
  --name-status                                       # show only names and status of changed files
  --svn                                               # use svn compatible diff format
  --git                                               # use git compatible diff format
  --json                                              # output in json format
]

# Remove stash entry from stack
export extern "arc stash drop" [
  stash?: string@"nu-complete arc stash-list"
  --quiet(-q)                                         # be quiet
]

# Remove all entries from stash stack
export extern "arc stash clear" []

# Create and check out a new branch and apply stash entry
export extern "arc stash branch" [
  branchname: string                                  # branch name to create
  stash?: string@"nu-complete arc stash-list"         # stash entry reference
  --quiet(-q)                                         # suppress progress reporting
]

# Initialize environment for a local or bare repository
export extern "arc init" [
  path?: string                                        # path to initialize
  --repository(-r): string                             # name of the repository
  --server(-s): string                                 # address of arc service
  --port(-p): string                                   # port of arc data service
  --ssl: any                                           # use ssl connection to server
  --object-store: string                               # shared store for storing objects of multiple mounts
  --object-store-type: string                          # object store type ('default' or 'sharded')
  --auth-type: string                                  # authentication type (passport)
  --preset: string                                     # preset containing default config values
  --at: string                                         # initial branch/commit/revision
  --bare                                               # initialize bare repository
  --skip-prefetch                                      # skip prefetch files when branch is being checkouted
]

# Create or list tags
export extern "arc tag" [
  tagname?: string@"nu-complete arc tags"             # tag to create or operate on
  commit?: string@"nu-complete arc refs"              # commit to tag, HEAD by default
  --list(-l)                                          # list tags
  --all(-a)                                           # list both remote-tracking and local tags
  --delete(-d): string@"nu-complete arc tags"         # delete a tag
  --force(-f)                                         # set tag even if it exists
  --points-at: string@"nu-complete arc refs"          # print only tags of the object
]

# Use binary search to find the commit that introduced a bug
export extern "arc bisect" []

# Reset bisect state and start bisection
export extern "arc bisect start" [
  bad?: string@"nu-complete arc commits all"   # a commit that is known to contain the bug
  good?: string@"nu-complete arc commits all"  # a commit that is known to be before the bug was introduced
  --no-checkout                                # do not checkout at each iteration, the head is accessible via `arc bisect head`
  --first-parent                               # follow only the first parent commit upon seeing a merge commit
]

# Mark the current commit as bad
export extern "arc bisect bad" []

# Mark the current commit as good
export extern "arc bisect good" []

# Automatically bisect by running a command on each commit
export extern "arc bisect run" []

# Get current bisect head
export extern "arc bisect head" []

# Reset bisect state
export extern "arc bisect reset" []

def "nu complete arc help options" [] {[
  {value: man, description: "Man page format, the most convenient way to see the docs"},
  {value: simple, description: 'Simple text in pager like "less". Used if current system does not support man pager'},
  {value: troff, description: "Man page formatter, can be used with another tool to read man"}
]}
def "nu complete arc help subcommands" [] {[
  {value: env, description: "Print docs about environment variables"},
  {value: commands, description: "Print all arc commands in readable format (doesn't support --format)"},
  {value: config, description: "Print docs about config variables"},
]}
# Show arc documentation
export extern "arc help" [
  topic: string@"nu complete arc help subcommands" # topic to show help for
  --format: string@"nu complete arc help options"  # output format, supported: man, simple, troff
]

# Remove untracked files from the working tree
export extern "arc clean" [
  ...paths: string                                    # limit cleaning to the given paths
  -d                                                  # remove untracked directories
  -x                                                  # remove ignored files, too
  -X                                                  # remove only ignored files
  --dry-run(-n)                                       # dry run
  --quiet(-q)                                         # do not print names of files removed
]

# Copy a file, a directory, or a symlink
export extern "arc cp" [
  commit_or_source: string@"nu-complete arc refs"     # commit to copy from, or the source path
  ...paths: string                                    # source and destination paths
  -r                                                  # allow recursive copy
  --cached                                            # record a copy that has already occurred (copy in index)
  --force(-f)                                         # force copy even if target exists
]

# Move or rename a file, a directory, or a symlink
export extern "arc mv" [
  ...paths: string                                    # source(s) and destination
  -k                                                  # skip move/rename errors
  --cached                                            # record a rename that has already occurred (move in index)
  --force(-f)                                         # force move/rename even if target exists
]

# Encrypt file
export extern "arc encrypt" [
  secret_id: string                                   # id of the secret to encrypt with
  ...paths: string                                    # files to encrypt
]

# Modify copy info of a single file or directory
export extern "arc copy-info" []

# Set copy-info for staged files
export extern "arc copy-info set" [
  commit_or_source: string@"nu-complete arc refs"     # commit to take the source from, or the source path
  ...paths: string                                    # source and destination paths
  --auto-add(-a)                                      # add the specified paths to the index before performing the operation
]

# Remove copy-info from index
export extern "arc copy-info remove" [
  ...paths: string                                    # paths to remove copy-info from
]

# Run merge conflict resolution tools to resolve merge conflicts
export extern "arc mergetool" [
  ...paths: string                                    # limit the run to the given paths
  --tool(-t): string@"nu-complete arc merge tools"    # specify tool to run
  --tool-help                                         # list available merge tools
  --no-prompt(-y)                                     # do not prompt
]

# View diff using difftools
export extern "arc difftool" [
  ...args: string@"nu-complete arc files-or-refs"     # commits and/or paths to diff
  --tool(-t): string@"nu-complete arc diff tools"     # specify tool to run
  --tool-help                                         # list available diff tools
  --no-prompt(-y)                                     # do not prompt
]

# Describe a commit using the most recent tag reachable from it
export extern "arc describe" [
  commit?: string@"nu-complete arc refs"              # commit-ish to describe, HEAD by default
  --all                                               # use any ref
  --long                                              # always use long format
  --first-parent                                      # only follow first parent
  --exact-match                                       # only output exact matches
  --match: string                                     # only consider tags matching <pattern>
  --exclude: string                                   # do not consider tags matching <pattern>
  --always                                            # show abbreviated commit object as fallback
  --dirty                                             # append <mark> on dirty working tree, '-dirty' by default
  --candidates: int                                   # consider <n> most recent tags
  --svn                                               # use svn revisions as tags
]

# Show information about files in the index and the working tree
export extern "arc ls-files" [
  ...paths: string                                    # limit the output to the given paths
  --cached(-c)                                        # show cached files in the output
  --deleted(-d)                                       # show deleted files in the output
  --modified(-m)                                      # show modified files in the output
  --others(-o)                                        # show other files in the output
]

# Show commits' merge base
export extern "arc merge-base" [
  left: string@"nu-complete arc refs"
  right: string@"nu-complete arc refs"
  --leftmost                                          # follow first parent for left commit, full-topo for right commit
  --force-local                                       # force local computation of merge-base (slow)
  --json                                              # output in json format
  --quiet(-q)                                         # be quiet
]

# Show working tree root
export extern "arc root" [
  --from-cwd                                          # relative path to current work dir
]

# Show various types of objects
export extern "arc show" [
  ...commits: string@"nu-complete arc refs"           # commit or branch name, `COMMIT:PATH` shows the file content
  --oneline                                           # print commit info in one line
  --stat                                              # show diffstat
  --name-only                                         # show only names of changed files
  --name-status                                       # show only names and status of changed files
  --unified(-U): int                                  # generate diffs with <n> lines of context
  --patience                                          # generate a diff using the 'patience diff' algorithm
  --reverse(-R)                                       # (experimental) reverse diff sides
  --resolve-moves: string                             # (experimental) resolve and show path copies & moves
  --relative: string                                  # exclude changes outside <path> and show pathnames relative to it
  --binary                                            # output a binary diff
  --svn                                               # use svn compatible diff format
  --git                                               # use git compatible diff format
  --json                                              # output in json format
  --attrs                                             # show attributes
  --no-decorate                                       # do not print branch info if any
  --color: string@"nu-complete arc color"             # set color mode
  --no-color                                          # set color mode never
  --quiet(-q)                                         # suppress diff output
]

# Show what revision and author last modified each line of a file to praise them
export extern "arc praise" [
  commit_or_path: string@"nu-complete arc files-or-refs" # commit to praise at, or the file itself
  path?: string                                          # file to praise
  --revisions(-r)                                        # show revision numbers
  -s                                                     # suppress author name and timestamp
  --json                                                 # output in json format
  -w                                                     # ignore whitespace when comparing lines
  --ignore-rev: string@"nu-complete arc commits all"     # ignore changes made by the provided revision
  --ignore-revs-file: string                             # ignore changes made by revisions listed in provided file
  --show-pulls                                           # also consider merge commits that are TREESAME to a later parent only
  -L: string                                             # annotate only the specified lines, <start>,<end>
  --first-parent                                         # walk through first parent only
  --full-topo                                            # full topology history walk
]

# Revert some existing commits
export extern "arc revert" [
  ...commits: string@"nu-complete arc commits all"     # commits to revert
  --edit(-e)                                           # edit the commit message
  --no-edit                                            # don't edit the commit message
  --no-commit(-n)                                      # don't automatically commit
  --mainline(-m): int                                  # parent number
  -X: string@"nu-complete arc strategy options"        # pass the argument through to the merge strategy
  --allow-empty                                        # revert even if the result has the same tree as its parent
  --continue                                           # resume revert sequence
  --abort                                              # abort and check out the original branch
  --skip                                               # skip current commit and continue
  --force(-f)                                          # revert even if prohibited by config or if it is not in the current branch
  --quiet(-q)                                          # be quiet
]

# Prune older reflog entries
export extern "arc reflog expire" [
  ...refs: string@"nu-complete arc refs"
  --expire: string                                    # prune entries older than the specified time
  --updateref                                         # update the reference to the value of the top reflog entry
  --rewrite                                           # adjust the "old" SHA-1 of an entry whose predecessor was pruned
  --dry-run(-n)                                       # do not actually prune any entries, just show what would have been pruned
  --verbose(-v)                                       # print extra information on screen
]

# Delete single entries from the reflog
export extern "arc reflog delete" [
  ...entries: string                                  # entries like <ref>@{<n>}
  --updateref                                         # update the reference to the value of the top reflog entry
  --rewrite                                           # adjust the "old" SHA-1 of an entry whose predecessor was pruned
  --dry-run(-n)                                       # do not actually prune any entries
  --verbose(-v)                                       # print extra information on screen
]

# Check whether a ref has a reflog
export extern "arc reflog exists" [
  ref: string@"nu-complete arc refs"
]

# Submit changes for review via Pull Request
export extern "arc submit" [
  ...paths: string                                    # limit the submit to the given paths
  --message(-m): string                               # pull request message
  --file(-F): string                                  # read message from file
  --edit(-e)                                          # further edit message taken from file with -F, command line with -m
  --no-edit                                           # use the selected message without launching an editor
  --to: string@"nu-complete arc branches"             # target branch
  --reviewer(-r): string                              # add reviewer to the pull request, can be used multiple times
  --label: string                                     # add label to the pull request, can be used multiple times
  --publish                                           # enable auto publish setting, ci-success/disabled/upload
  --auto(-A)                                          # shortcut for --publish --no-code-review --merge
  --merge(-M)                                         # enable automatic merging
  --code-review                                       # enable arcanum Code Review check
  --no-code-review                                    # disable arcanum Code Review check
  --view                                              # open the pull request in a web browser
  --all                                               # submit untracked files
  --new                                               # create new PR from current unsubmitted changes
  --stack                                             # create new PR that includes current submitted and unsubmitted changes
  --abort                                             # abort and check out the original state
  --no-verify(-n)                                     # bypass pre-commit hooks
  --skip-hook: string                                 # skip specific pre-commit hook
  --skip-linter: string                               # skip specific linter in format <glob>:<linter-id>
]

# Remove local entries of remote refs, hides them from view without deleting from server
export extern "arc unfetch" [
  remote_ref: string@"nu-complete arc fetchable branches" # name of remote ref to remove, without the 'arcadia/' prefix
  --force(-f)                                            # force unfetch over sanity checks (e.g. allow unfetching trunk)
]

# Create, discard, list or checkout pull-requests
export extern "arc pr" []

# Create new pull request
export extern "arc pr create" [
  --message(-m): string                                # pull request message
  --file(-F): string                                   # read message from file
  --edit(-e)                                           # further edit message taken from file with -F, command line with -m
  --no-edit                                            # use the selected message without launching an editor
  --to: string@"nu-complete arc branches"              # target branch
  --reviewer(-r): string                               # add reviewer to the pull request, can be used multiple times
  --label: string                                      # add label to the pull request, can be used multiple times
  --publish                                            # enable auto publish setting, ci-success/disabled/upload
  --auto(-A)                                           # shortcut for --publish --no-code-review --merge
  --merge(-M)                                          # enable automatic merging
  --code-review                                        # enable arcanum Code Review check
  --no-code-review                                     # disable arcanum Code Review check
  --view                                               # open the pull request in a web browser
  --no-commits                                         # do not include commit messages to pull request's description
  --push                                               # push local commits and/or create a remote branch (default)
  --no-push                                            # don't push local commits and don't create a remote branch
  --keep-branch                                        # keep source remote branch after successful merging
  --follow                                             # trace status of the pull request and wait until it will be merged
  --wait(-w)                                           # wait until PR will be uploaded to Arcanum
  --force(-f)                                          # force creation of pull request
  --no-verify                                          # do not run pre-push hooks
  --json                                               # output in json format
  --quiet(-q)                                          # be quiet
]

# Checkout pull request or review
export extern "arc pr checkout" [
  pr: string@"nu-complete arc pull-requests"           # pull request id
  --iteration(-i): int                                 # iteration of a pull request, latest is default
  --detached(-d)                                       # checkout to detached HEAD instead of a branch
  --dirty                                              # reset changes in PR, they'll be moved to stage, implies --detached
  --force(-f)                                          # force checkout (throw away local modifications)
  --quiet(-q)                                          # be quiet
]

# List pull requests
export extern "arc pr list" [
  path?: string                                        # limit the list to PRs touching the path
  --in(-i)                                             # show incoming PRs where you are subscriber
  --out(-o)                                            # show outgoing PRs where you are author or coauthor (default)
  --all                                                # all PRs
  --draft(-d)                                          # show only draft PRs
  --no-draft                                           # don't show draft PRs
  --author(-A): string                                 # filter by author, use !VAL for negation
  --reviewer(-R): string                               # filter by reviewer, use !VAL for negation
  --status(-S): string@"nu-complete arc pr statuses"   # filter by PR status
  --owner: string                                      # filter by owner, use !VAL for negation
  --subscriber: string                                 # filter by subscriber, use !VAL for negation
  --ticket: string                                     # filter by ticket, use !VAL for negation
  --label: string                                      # filter by label, use !VAL for negation
  --shipper: string                                    # show PRs that were already shipped by VAL, use !VAL for negation
  --limit(-l): int                                     # limit the number of displayed PRs
  --as: string                                         # view as other user
  --sort: string@"nu-complete arc pr sort"             # sort PRs by status, date, summary or id
  --asc                                                # ascending sort order
  --desc                                               # descending sort order
  --json                                               # output in jsonl (stream of json objects) format
]

# Extended status information about pull request
export extern "arc pr status" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
  --short(-s)                                          # show status concisely
  --follow                                             # trace status of the pull request
  --json                                               # output in json format
]

# View pull request in the browser
export extern "arc pr view" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
]

# Publish draft pull request
export extern "arc pr publish" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
]

# Discard open pull request
export extern "arc pr discard" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
  --allow-other                                        # discard other user's PR
]

# Change pull request merge settings
export extern "arc pr merge" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
  --auto(-A)                                           # enable automatic merging (automerge)
  --no-auto                                            # disable automatic merging (automerge)
  --now                                                # try to merge PR now, if requirements are satisfied
  --force                                              # force merge PR ignoring any checks, works only with --now
  --wait                                               # synchronous mode, wait for PR to be merged
  --timeout: string                                    # time to wait for PR to be merged
  --json                                               # output in json format
]

# View PR changes
export extern "arc pr changes" [
  pr?: string@"nu-complete arc pull-requests"          # arbitrary pr id, implies --submitted
  --submitted(-S)                                      # view changes of last submitted to PR
]

# View PR changes history
export extern "arc pr history" [
  pr?: string@"nu-complete arc pull-requests"          # arbitrary pr id, implies --submitted
  --submitted(-S)                                      # view history only of submitted PR changes
  --json                                               # output in json format
]

# Manage shared access to a pull request
export extern "arc pr share" [
  pr?: string@"nu-complete arc pr targets"             # pull request id or branch, current branch by default
  --with: string                                       # share the pull request with the given user, can be used multiple times
  --with-all                                           # share the pull request with everyone
  --reset                                              # revoke shared access
  --quiet(-q)                                          # be quiet
]

# Open text interface to checkout PR
export extern "arc pr select" []

# Verify the connectivity and validity of the objects in the database
export extern "arc fsck" []

# Check consistency of vcs objects
export extern "arc fsck objects" [
  ...args: string
]

# Check consistency of vfs overlay
export extern "arc fsck overlay" [
  path: string                                         # path to the mount point
  --log: string                                        # path to log file
  --load-objects                                       # load non-local vcs objects required for hash check
  --no-progress                                        # do not print progress to stderr
  --dry-run(-n)                                        # check, but do not change anything
  --no-prompt(-y)                                      # assume an answer of 'yes' to all questions
  --verbose(-v)                                        # verbose output
]

# Export a named tree
export extern "arc export" [
  commit: string@"nu-complete arc refs"                # commit to export
  ...paths: string                                     # paths to export
  --to: string                                         # file system path where the files will be exported
  --overwrite                                          # overwrite existing files
  --verbose(-v)                                        # report progress to stderr
]

# Cleanup object store
export extern "arc gc" [
  --dry-run(-n)                                        # show what would be collected
  --truncate                                           # [USE WITH CAUTION] truncate storage without checking object presence on the server
]

# Manage user configuration
export extern "arc config" [
  key?: string@"nu-complete arc config keys"           # config key
  value?: string                                       # value to set
  --list(-l)                                           # list existing options
  --name-only                                          # show only names for --list
  --unset                                              # unset option
  --remove-section                                     # remove section with all its options
  --file: string                                       # config file used to set values
]

# Show current branch information
export extern "arc info" [
  --json                                               # output in json format
  --mount                                              # output mount-specific info
  --ahead-behind                                       # display detailed ahead/behind counts
]

# List the contents of a tree object
export extern "arc ls-tree" [
  commit: string@"nu-complete arc refs"
  path?: string
  -d                                                   # only show trees (implies -t)
  -r                                                   # recurse into subtrees
  -t                                                   # show trees when recursing
  --name-only                                          # list only filenames
  --full-name                                          # use full path names
  --traverse-blobrefs                                  # show blobref parts
  --json                                               # output in json format
]

# Parse revision or revision range
export extern "arc rev-parse" [
  ...args: string@"nu-complete arc refs"
  --sq                                                 # make output a single line, properly quoted for consumption by shell
  --sq-quote                                           # mode that does only quoting
  --not                                                # prefix object names with ^ and strip existing ^ prefixes
  --default: string                                    # use this arg if there is no parameter given by the user
  --quiet                                              # do not output an error message if the argument is not a valid object name
  --arc-dir                                            # show the path to the .arc directory
  --is-inside-arc-dir                                  # check whether cwd is inside the .arc directory
  --is-inside-work-tree                                # check whether cwd is inside the working tree
  --is-bare-repository                                 # check whether the repository is bare
  --is-local-repository                                # check whether the repository is local
  --show-prefix                                        # show the path of cwd relative to the repository root
  --show-toplevel                                      # show the absolute path of the repository root
]

# Show information about current user
export extern "arc user-info" [
  --update                                             # load user information from server
  --json                                               # print info as json
]

# Acquire arc token with ssh key
export extern "arc token" []

# Store token to ~/.arc/token
export extern "arc token store" []

# Print token
export extern "arc token show" []

# Generate new encryption key and store it in YAV
export extern "arc gen-key" []

def "nu-complete arc shells" [] {
  ['bash', 'zsh']
}

# Generate tab completion scripts for zsh or bash
export extern "arc completion" [
  shell: string@"nu-complete arc shells"               # shell syntax for completion script
]

# Initialize environment with virtual working tree
export extern "arc mount" [
  mount_point?: string                                 # path to mount the working tree at
  --mount(-m): string                                  # mount path
  --repository(-r): string                             # name of the repository
  --object-store: string                               # shared store for storing objects of multiple mounts
  --object-store-type: string                          # object store type ('default' or 'sharded')
  --override-object-store                              # allow override object store path using --object-store
  --server: string                                     # address of vcs data service
  --port(-p): string                                   # port of vcs data service
  --ssl: any                                           # use ssl connection to server
  --pull-server: string                                # address of vcs pull service
  --pull-port: string                                  # port of vcs pull service
  --pull-ssl: any                                      # use ssl connection to pull service
  --arcanum-url: string                                # arcanum api endpoint url
  --auth-type: string                                  # authentication type (passport)
  --preset: string                                     # preset containing default config values
  --local                                              # initialize local repository
  --read-only                                          # mount filesystem read-only
  --path-filter: string                                # (experimental) path filter for selective checkout
  --foreground(-F)                                     # run FUSE in foreground mode
  --debug(-D)                                          # enable debug logs
  --log: string                                        # path to log file
  --json-trace: string                                 # path to json trace (chromium format) file
  --allow-root                                         # allow root access to the mounted filesystem
  --allow-other                                        # all users (including root) can access the files in FUSE
  --no-auto-unmount                                    # disable auto_unmount option
  -o: string                                           # extra mount option (advanced)
  --vfs-version: string                                # [DEPRECATED] does nothing
  --inode-cache-size: int                              # inode cache items
  --overlay-rocks-block-cache-size: int                # overlay rocksdb block cache size
  --fuse-threads: int                                  # number of FUSE io threads
  --fuse-timeout: string                               # timeout for fuse operations
  --no-aggressive-delete                               # (mac only) do not delete data after last RELEASE or UNLINK
  --invalidate-inodes                                  # (mac only) invalidate inodes on closing files
  --checkout-prepared-timeout: string                  # timeout before prepared checkout is destroyed
  --node-rw-locks: any                                 # enable support for read/write node locking
  --cache-size(-C): int                                # memory size for cache in bytes
  --monitoring-port                                    # start monitoring server on port, 8089 by default
  --ssh-tokens                                         # force arc to use ssh to get YAV and ARC tokens
  --no-ssh-tokens                                      # force disable arc to use ssh to get YAV and ARC tokens
  --disable-mount-manager                              # do not manage given mount point and disable mount checks
  --new-overlay                                        # create new overlay to decrease local repository load
  --list(-l)                                           # show list of managed mount points
  --json                                               # output in json format
]

# Close environment for a local repository with virtual working tree
export extern "arc unmount" [
  path?: string                                        # path to the repository
  --list(-l)                                           # show list of mounted and unmounted repositories
  --forget                                             # [USE WITH CAUTION] remove mount from .arc/mount-points and remove corresponding storage
  --force(-f)                                          # force unmount repository
]

# Synchronize working copy with remote one
export extern "arc sync" []

# Start sync
export extern "arc sync start" [
  --include-untracked(-u)                              # sync untracked files
  --wave-branch: string                                # use special branch for synchronization
  --domain: string                                     # prefix automatically generated branch with the given token
  --foreground(-f)                                     # run sync in foreground mode
  --interval(-n): int                                  # sync interval, seconds
  --remote-follow(-r): string                          # also try to run follower on the remote host, HOST[:PORT]:PATH
  --force-follow                                       # discard all changes for the remote follower when using --remote-follow
]

# Follow a synchronized working copy
export extern "arc sync follow" [
  ref?: string@"nu-complete arc refs"
  --interval(-n): int                                  # poll interval, seconds
  --foreground(-f)                                     # run following in foreground
  --force                                              # discard all local changes
  --wait-wave: int                                     # wait for wave-branch to appear if it does not exist, seconds
  --remote(-r): string                                 # run this command on the remote host, HOST[:PORT]:PATH
]

# Stop sync
export extern "arc sync stop" [
  --force(-f)                                          # force stop synchronization
  --no-wait                                            # do not wait for the actual completion of the sync
  --remote(-r): string                                 # run this command on the remote host, HOST[:PORT]:PATH
]

# Sync status
export extern "arc sync status" [
  --json                                               # print status in json format
  --remote(-r): string                                 # run this command on the remote host, HOST[:PORT]:PATH
]

# Do force update of a synchronized working copy
export extern "arc sync update" [
  --wait-remote(-r): string                            # wait for remote repository to update, HOST[:PORT]:PATH
]

# Monitor file events in working tree to speed up status
export extern "arc monitor" []

# Start monitoring
export extern "arc monitor start" [
  --foreground(-f)                                     # run monitor in foreground mode
  --new-index                                          # recreate file index database
]

# Stop monitoring
export extern "arc monitor stop" [
  --force(-f)                                          # force stop FsMonitor
  --no-wait                                            # do not wait for stopping FsMonitor
]

# Turn monitoring on/off for repository
export extern "arc monitor setup" [
  --on                                                 # enable FsMonitor for repository
  --off                                                # disable FsMonitor for repository
  --auto                                               # enable and autorestart FsMonitor for repository
]

export extern "arc" [
  command?: string@"nu-complete arc subcommands"   # Subcommands
  --version(-v)                                    # Prints the Arc suite version that the arc program came from
  --svnrevision                                    # Prints the svn revision
  --help(-h)                                       # Prints the synopsis and a list of the most commonly used commands
  --update                                         # Update arc client
  --has-update                                     # Check whether arc client update is available
  --set-channel                                    # Set arc client release channel [stable, prestable, unstable, testing]
  --is-launcher                                    # Check whether arc client is run through launcher script
  --remove-unused-versions                         # Remove old arc client releases
]
