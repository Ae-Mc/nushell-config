const commands = ['arc', 'git', 'zoxide']

mut sources = []

for command in $commands {
    if (which $command | is-not-empty) {
        let alias_path = $'aliases/($command)/'
        let completions_path = $'completions/($command)-completions'
        if ($alias_path | path exists) {
            $sources ++= [$alias_path]
        }
        if ($'($completions_path).nu' | path exists) {
            $sources ++= [$'($completions_path).nu']
        } else if ($'($completions_path)/' | path exists) {
            $sources ++= [$'($completions_path)/']
        } 
    }
}

if ($sources | is-not-empty) {
    'use ' + ($sources | str join " *\nuse ") + " *\n" | save -f ./.sources.nu
} else {
    '' | save -f ./.sources.nu
}
