export DISABLE_SPRING=true

export BUN_INSTALL="$HOME/.bun"
export PNPM_HOME="$HOME/Library/pnpm"
export POSTGRES_HOME="/Applications/Postgres.app/Contents/Versions/17/bin"
export WINDSURF_HOME="$HOME/.codeium/windsurf/bin"

export PATH="$PATH:$HOME/bin:/usr/local/bin:$HOME/.local/bin"

export ZSH="$HOME/.oh-my-zsh"

#ZSH_THEME="robbyrussell"
ZSH_THEME="crunch"

ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
# DISABLE_UNTRACKED_FILES_DIRTY="true"
plugins=(git asdf)

source $ZSH/oh-my-zsh.sh

# User configuration
# export ARCHFLAGS="-arch x86_64"
alias ls="eza"
alias vi="nvim"
alias viconfig="nvim ~/.config/nvim"
alias c="claude-wrapper"
alias zshconfig="nvim ~/.zshrc"

eval "$(starship init zsh)"

# Conditionally add stuff to path
if [[ -d "$PNPM_HOME" ]]; then
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PATH:$PNPM_HOME" ;;
  esac
fi
if [[ -d "$BUN_INSTALL" ]]; then
  case ":$PATH:" in
    *":$BUN_INSTALL:"*) ;;
    *) export PATH="$PATH:$BUN_INSTALL/bin" ;;
  esac
fi
if [[ -d "$WINDSURF_HOME" ]]; then
  case ":$PATH:" in
    *":$WINDSURF_HOME:"*) ;;
    *) export PATH="$PATH:$WINDSURF_HOME" ;;
  esac
fi
if [[ -d "$POSTGRES_HOME" ]]; then
  case ":$PATH:" in
    *":$POSTGRES_HOME:"*) ;;
    *) export PATH="$PATH:$POSTGRES_HOME" ;;
  esac
fi

[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

eval "$(mise activate zsh)"

export EDITOR="nvim"
