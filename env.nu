# env.nu
#
# Installed by:
# version = "0.105.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.
if (which code | length) != 0 {
    $env.EDITOR = "code"
} else if (which nvim | length) != 0 {
    $env.EDITOR = "nvim"
} else {
    $env.EDITOR = "vi"
}
$env.config.edit_mode = "vi"

let DOWNLOADABLE_MODULES_DIR = ($nu.config-path | path dirname | path join "modules-ext")
$env.NU_LIB_DIRS ++= [$DOWNLOADABLE_MODULES_DIR]
if not ($DOWNLOADABLE_MODULES_DIR | path exists)  {
    mkdir $DOWNLOADABLE_MODULES_DIR
}

const os = $nu.os-info.name;

match $os {
    'windows' => {
        $env.Path = ($env.Path | prepend 'C:\Program Files\WinGet\Links')
    }
}

# External modules installation
let packages = match $os {
    'android' => {
        let is_termux = which termux-setup-storage | is-not-empty
        if $is_termux {
            {
                carapace : 'pkg install carapace'
                oh-my-posh: 'pkg install oh-my-posh'
                zoxide: 'pkg install zoxide'
            }
        } else {
            error make {msg: "Unsupported platform"}
        }
    }
    'windows' => {
        carapace: 'winget install -e --id rsteube.Carapace'
        oh-my-posh: (
            'winget install JanDeDobbeleer.OhMyPosh'
            + ' --source winget --scope machine --force'
        )
        zoxide: 'winget install ajeetdsouza.zoxide --scope machine'
    }
    * => {
        error make {msg: "Unsupported platform"}
    }
} | transpose cmd install

$packages | each { |e| 
    if (which $e.cmd | is-empty) {
        print $'Installing ($e.cmd)'
        try {
            nu -c $e.install
        } catch { |err| 
            print $"Error installing ($e.cmd)"
            print $err 
        }
    }
}

const AUTOLOAD_DIR = $nu.data-dir | path join "vendor/autoload"
mkdir $AUTOLOAD_DIR

const ZOXIDE_INIT_PATH = $nu.data-dir | path join .zoxide.nu
if not ($ZOXIDE_INIT_PATH | path exists) {
    zoxide init nushell | save $ZOXIDE_INIT_PATH
}

# Better autocompletions
$env.CARAPACE_BRIDGES = 'inshellisense' # optional
const CARAPACE_INIT = ($AUTOLOAD_DIR | path join 'carapace-init.nu')
if not ($CARAPACE_INIT | path exists) {
    carapace _carapace nushell | save $CARAPACE_INIT
}

# Plugin manager install
def _load_folders_from_repo [repo: string, folders: list<string>] {
    git clone -n --depth=1 --filter=tree:0 $repo
    let repo_name = ($repo | path basename)
    print $repo_name
    cd $repo_name
    let folders_str = ($folders | str join " ")
    git sparse-checkout set --no-cone $folders_str
    git checkout
    cd ..
}

let NUPM_PATH = ($DOWNLOADABLE_MODULES_DIR | path join "nupm")
let current_folder = pwd
if not ($NUPM_PATH | path exists) {
    cd $DOWNLOADABLE_MODULES_DIR
    _load_folders_from_repo https://github.com/nushell/nupm ["nupm"]
    cd $current_folder
}
$env.NU_LIB_DIRS ++= [ $DOWNLOADABLE_MODULES_DIR ]
