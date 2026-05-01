export DISABLE_SPRING=true

export BUN_BIN="$HOME/.bun"
export PNPM_HOME="$HOME/Library/pnpm"
export POSTGRES_BIN="/Applications/Postgres.app/Contents/Versions/17/bin"
export WINDSURF_BIN="$HOME/.codeium/windsurf/bin"
export ANTIGRAVITY_BIN="$HOME/.antigravity/bin"
export OPENCODE_BIN="$HOME/.opencode/bin"
export NVIM_BIN="/opt/nvim/bin" # ubuntu

export PATH="$PATH:$HOME/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.local/binlinks"

export ZSH="$HOME/.oh-my-zsh"
export TERM=xterm
export MANPAGER="gum pager"

# Avoid issues with `gpg` as installed via Homebrew.
# https://stackoverflow.com/a/42265848/96656
export GPG_TTY=$(tty);
# export ARCHFLAGS="-arch x86_64"

#ZSH_THEME="robbyrussell"
ZSH_THEME="crunch"

# ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
# DISABLE_UNTRACKED_FILES_DIRTY="true"
plugins=(git asdf)

source $ZSH/oh-my-zsh.sh
# Broot
source $HOME/.config/broot/launcher/bash/br

export EDITOR="nvim"

# Git completion
fpath=(~/.zsh $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash

# fzf
# Handle ignoring files via .fdignore
source ~/.zsh/fzf.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

eval "$(zoxide init zsh)"

alias ls="eza -al --icons --git --smart-group --time-style long-iso --no-permissions --links --changed"
alias tree="eza --tree -al --icons --git --smart-group --time-style long-iso --no-permissions --links --changed"
alias b="broot"
alias vi="nvim"
alias c="claude-wrapper"
alias viconfig="$EDITOR $HOME/.config/nvim"
alias gconfig="$EDITOR $HOME/.config/ghostty/config"
alias zshconfig="$EDITOR $HOME/.zshrc"
alias mem="top -l1 | grep PhysMem"
alias proxy="ssh -C2qTnN -D 2000"
alias expand="atool -x"
alias du="dust"
alias df="duf"
alias digs="dig +nocmd "$1" any +multiline +noall +answer | gum filter"
alias curl="curlie"
alias cat='bat -P --decorations=auto'
alias diff="batdiff"
alias bathelp="bat --plain --language=help"
alias uninstall="brew list | gum choose --no-limit | xargs brew uninstall"
alias please="gum input --password | sudo -nS"
alias up='source ~/.local/bin/up'

# Conditional paths
for bin_dir in "$ANTIGRAVITY_BIN" "$PNPM_HOME" "$BUN_BIN" "$WINDSURF_BIN" "$POSTGRES_BIN" "$OPENCODE_BIN" "$NVIM_BIN"; do
  if [[ -d "$bin_dir" ]]; then
    case ":$PATH:" in
      *":$bin_dir:"*) ;;
      *) export PATH="$PATH:$bin_dir" ;;
    esac
  fi
done

[ -s "$BUN_BIN/_bun" ] && source "$BUN_BIN/_bun"

eval "$(mise activate zsh)"
eval "$(starship init zsh)"

fortune | cowsay | lolcat # greeting

if [[ -n "\$PS1" ]] && [[ -z "\$TMUX" ]] && [[ -n "\$SSH_CONNECTION" ]]; then
  tmux attach-session -t remote || tmux new-session -s remote
fi

# TODO: fzf completion options in https://github.com/coderabbitai/dotfiles/blob/master/dot_zshrc
