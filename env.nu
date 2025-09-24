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

const os = $nu.os-info.name;
mut is_ubuntu = false
def --env _prepend_path_if_exists [p: path] {
    if ($p | path expand | path exists) {
        $env.PATH = ($env.PATH | prepend ($p | path expand))
    }
}

match $os {
    'windows' => {
        _prepend_path_if_exists 'C:/Program Files/carapace/bin'
        _prepend_path_if_exists 'C:/Program Files/oh-my-posh/bin'
        _prepend_path_if_exists 'C:/Program Files/zoxide/bin'
        _prepend_path_if_exists 'C:/Program Files/WinGet/Links'
        _prepend_path_if_exists '~/AppData/Local/Microsoft/WinGet/Links/'
    }
    'linux' => {
        if (which lsb_release | is-not-empty) {
            if (lsb_release -i | str downcase) =~ 'ubuntu' {
                $is_ubuntu = true
                _prepend_path_if_exists '~/.local/bin/'
            }
        }
    }
}

# External modules installation
let packages = match $os {
    'android' => {
        let is_termux = which termux-setup-storage | is-not-empty
        if $is_termux {
            {
                carapace: 'pkg install carapace'
                oh-my-posh: 'pkg install oh-my-posh'
                zoxide: 'pkg install zoxide'
            }
        } else {
            error make {msg: "Unsupported platform"}
        }
    }
    'windows' => {
        carapace: 'winget install rsteube.Carapace --scope machine'
        oh-my-posh: (
            'winget install JanDeDobbeleer.OhMyPosh'
            + ' --source winget --scope machine --force'
        )
        zoxide: 'winget install ajeetdsouza.zoxide --scope machine'
    }
    'linux' => {
        if ($is_ubuntu) {
            {
                carapace: `
                (sudo sh -c "echo 'deb [trusted=yes] https://apt.fury.io/rsteube/ /' > /etc/apt/sources.list.d/fury.list" ) ;
                sudo apt-get update ; sudo apt-get install carapace-bin
                `
                oh-my-posh: 'curl -s https://ohmyposh.dev/install.sh | bash -s'
                zoxide: 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
            }
        } else {
            print {"Unsupported platform! Use at your own risk!"}
        }
    }
    * => {
        print {"Unsupported platform! Use at your own risk!"}
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
zoxide init --no-cmd nushell | save -f $ZOXIDE_INIT_PATH

# Better autocompletions
$env.CARAPACE_BRIDGES = 'inshellisense' # optional
const CARAPACE_INIT = ($AUTOLOAD_DIR | path join 'carapace-init.nu')
carapace _carapace nushell | save -f $CARAPACE_INIT
