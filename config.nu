# config.nu
#
# Installed by:
# version = "0.105.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

let oh_my_posh = $nu.config-path | path dirname | path join oh-my-posh
let oh_my_posh_theme = $oh_my_posh | path join themes 1_shell.omp.json
oh-my-posh init nu --config $oh_my_posh_theme
source ($nu.data-dir | path join .zoxide.nu)

source ($nu.data-dir | path join .sources.nu)
$env.config.completions.algorithm = 'fuzzy'
$env.config.highlight_resolved_externals = true
$env.config.color_config.shape_external = 'red_bold'
$env.config.color_config.shape_external_resolved = 'yellow'
