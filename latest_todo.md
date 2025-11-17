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




JDR9-4VD2-CK5V-JVDK-6GP4-YWEM

