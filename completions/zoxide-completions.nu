def "nu-complete zoxide import" [] {
  ["autojump", "z"]
}

def "nu-complete zoxide shells" [] {
  ["bash", "elvish", "fish", "nushell", "posix", "powershell", "xonsh", "zsh"]
}

def "nu-complete zoxide hooks" [] {
  ["none", "prompt", "pwd"]
}

# Add a new directory or increment its rank
export extern "zoxide add" [
  ...paths: path
]

# Edit the database
export extern "zoxide edit" [ ]

# Import entries from another application
export extern "zoxide import" [
  --from: string@"nu-complete zoxide import"  # Application to import from
  --merge                                     # Merge into existing database
]

# Generate shell configuration
export extern "zoxide init" [
  shell: string@"nu-complete zoxide shells"
  --no-cmd                                    # Prevents zoxide from defining the `z` and `zi` commands
  --cmd: string                               # Changes the prefix of the `z` and `zi` commands [default: z]
  --hook: string@"nu-complete zoxide hooks"   # Changes how often zoxide increments a directory's score [default: pwd]
]

# Search for a directory in the database
export extern "zoxide query" [
  ...keywords: string
  --all(-a)             # Show unavailable directories
  --interactive(-i)     # Use interactive selection
  --list(-l)            # List all matching directories
  --score(-s)           # Print score with results
  --exclude: path       # Exclude the current directory
]

# Remove a directory from the database
export extern "zoxide remove" [
  ...paths: path
]

export extern zoxide [
  --help(-h)            # Print help
  --version(-V)         # Print version
]

const os_separator = if ($nu.os-info.name == "windows") { '\' } else { '/' }

def "nu-complete z path" [context: string] {
  let spans = $context | str trim --left | split row " "
  let last = $spans | last
  let separator = '/'
  let parts = $spans
    | skip 1
    | each { str downcase | str replace -ar '[/\\]' $separator }
  let zoxide_parts = $parts
    | each { str replace -ar '[/\\]' $os_separator }
  let paths = ^zoxide query -l --exclude $env.PWD ...$zoxide_parts
    | lines
    | each { str replace -ar '[/\\]' $separator }
  let result = $paths
    | each { |dir|
        if ($parts | length) <= 1 {
          {value: $dir}
        } else {
          let dir_lower = $dir | str downcase
          let rem_start = $parts | drop 1 | reduce --fold 0 { |part, rem_start|
            ($dir_lower | str index-of --range $rem_start.. $part) + ($part | str length)
          }
          {
            value: ($dir | str substring $rem_start..),
            description: $dir
          }
        }
      }
    | if (($in | is-empty) and ($spans | length) <= 2) {
        glob -d 1 ($last + '*') -F
          | each { |it|
            let x = $it
              | str substring ($last | path expand | str length)..
              | if $last ends-with '/' {
                  $in | str substring 1..
                } else if ($last ends-with '/.') {
                  $in | str substring 2..
                } else { $in }
            return {
              "value": ($last + $x + '/')
            }
          }
          | if ($in | is-empty) { [null] } else { $in }
      } else { $in }
  {
    options: {
      sort: false,
      completion_algorithm: "substring",
      case_sensitive: false,
    }
    completions: ($result | insert style steelblue1b)
  }
}

export def zoxide_completer_generator [] {
  print 'Generating zoxide completer...'
  return { |spans: list<string>|
    nu-complete z path ($spans | str join " ")
  }
}

export def z --env --wrapped [
  ...rest: string@"nu-complete z path"
] {
  __zoxide_z ...($rest | each { str replace -ar '[/\\]' $os_separator})
}
