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

overlay use nupm/nupm/
let oh_my_posh_themes = $nu.data-dir | path join oh-my-posh themes
let oh_my_posh_theme = $oh_my_posh_themes | path join 1_shell.omp.json
if not ($oh_my_posh_theme | path exists) {
    print 'Load theme from remote'
    mkdir $oh_my_posh_themes
    oh-my-posh config export --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/1_shell.omp.json --output $oh_my_posh_theme
}
oh-my-posh init nu --config $oh_my_posh_theme
