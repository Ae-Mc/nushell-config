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

def "nu-complete z path" [context: string] {
  let spans = $context | split row " "
  let path_parts = $spans | skip 1
  let path = $path_parts | str join " "
  mut $result = []
  mut result = ^zoxide query -l --exclude $env.PWD ...$path_parts | lines | each { |e| {"value": ($e | path basename), "description": $e}} | uniq-by value
  if ($result | is-empty) {
    let pwd_length = ($env.PWD | str length)
    mut $result = glob ($path + '*') -F
      | str substring ($pwd_length + 1)..
      | each { |e| (if ($path | str starts-with './') {'./'} else {''}) + $e + '/'}
    return (if ($result | is-empty) { [null] } else { $result })
  }
  return $result
}

export def zoxide_completer_generator [] {
  print 'Generating zoxide completer...'
  return { |spans: list<string>|
    nu-complete z path ($spans | str join " ")
  }
}

export def --env --wrapped z [
  ...rest: string@"nu-complete z path"
] {
  __zoxide_z ...$rest
}
