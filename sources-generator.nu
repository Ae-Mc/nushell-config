const commands = ['arc', 'git', 'zoxide']

mut sources = []

for command in $commands {
    if (which $command | is-not-empty) {
        let alias_path = $nu.config-path | path dirname | path join 'aliases' | path join $command
        let completions_path = $nu.config-path | path dirname | path join 'completions' | path join $'($command)-completions'
        if ($alias_path | path exists) {
            $sources ++= [$alias_path]
        }
        if ($'($completions_path).nu' | path exists) {
            $sources ++= [$'($completions_path).nu']
        } else if ($'($completions_path)/' | path exists) {
            $sources ++= [$'($completions_path)/']
        }
    } else {
    }
}


const SOURCES_PATH = ($nu.data-dir | path join .sources.nu)

if ($sources | is-not-empty) {
    ('use ' + ($sources | str join " *\nuse ") + " *\n") | save -f $SOURCES_PATH
} else {
    '' | save -f $SOURCES_PATH
}
