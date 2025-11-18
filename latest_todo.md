Install homebrew /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install git rsync
mkdir -p ~/code
git clone git@github.com:ericmhalvorsen/laptop.git ~/code/
cd ~/code/eaptop
brew install mise
mise install
mise exec -- mix deps.get
mise exec -- mix escript.build
mise exec -- ./vault restore -v /Volumes/Amythest/VaultBackup


Install breaks with No function no function clause matching in Owl.Data.do_chunk_by/5    
    
    The following arguments were given to Owl.Data.do_chunk_by/5

Restore has no progress

Breaks on photolibrary permissions

Cursor + VSCode

Licenses for Nord and Falcon

ExpressVPN

Postgres.app (added to brew) DONE
Docker added to brew DONE

softwareupdate --install-rosetta --agree-to-license (for docker when starting the machine)

Symlink nvim and dotfiles

WE WIPED OUT MY GIT REPOS lets def fix this one lololol


