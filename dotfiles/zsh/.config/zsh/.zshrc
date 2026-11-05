# ~/.config/zsh/.zshrc

# ---- istoric ----
HISTFILE="$HOME/.local/state/zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS

# ---- PATH ----
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

# ---- completare ----
fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ---- taste ----
bindkey -e
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3~'   delete-char
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line

# ---- plugin-uri (instalate din pacman) ----
for f in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/fzf/key-bindings.zsh /usr/share/fzf/completion.zsh; do
    [[ -r $f ]] && source "$f"
done

# ---- aliasuri ----
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias vim='nvim'
alias v='nvim'
alias g='git'
alias gs='git status -sb'
alias lg='lazygit'
alias d='docker'
alias dc='docker compose'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias ip='ip -c'
alias update='sudo pacman -Syu'
alias ports='ss -tulpn'
alias myip='curl -s https://ifconfig.me; echo'
alias reload='source ~/.config/zsh/.zshrc'

# ---- unelte ----
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=bg+:#14141f,hl:#ff2e63,hl+:#ff2e63,pointer:#08d9d6,prompt:#08d9d6,info:#8d93aa'
command -v zoxide   >/dev/null && eval "$(zoxide init zsh --cmd cd)"
command -v direnv   >/dev/null && eval "$(direnv hook zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"

# syntax highlighting trebuie încărcat ULTIMUL
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
    && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
