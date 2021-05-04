#!/usr/bin/env bash

forhg::warn() { printf "%b[Warn]%b %s\n" '\e[0;33m' '\e[0m' "$@" >&2; }
forhg::info() { printf "%b[Info]%b %s\n" '\e[0;32m' '\e[0m' "$@" >&2; }
# forhg::inside_work_tree() { git rev-parse --is-inside-work-tree >/dev/null; }
forhg::inside_work_tree() { hg root &> /dev/null; }

# https://github.com/wfxr/emoji-cli
hash emojify &>/dev/null && forhg_emojify='|emojify'

forhg_pager=${FORHG_PAGER:-$(hg config pager.pager || echo 'cat')}
forhg_show_pager=${FORHG_SHOW_PAGER:-$(hg config pager.pager || echo "$forhg_pager")}
forhg_diff_pager=${FORHG_DIFF_PAGER:-$(hg config pager.pager || echo "$forhg_pager")}
# forhg_ignore_pager=${FORGIT_IGNORE_PAGER:-$(hash bat &> /dev/null && echo 'bat -l gitignore --color=always' || echo 'cat')}

# forhg_log_format=${FORHG_LOG_FORMAT:-%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset}
# forhg_log_format=${FORHG_LOG_FORMAT:-\{node\|short\} \| \{author\|user\} \| \{date\|isodatesec\} \| \{desc\|strip\|firstline\}\n}
forhg_log_format=${FORHG_LOG_FORMAT:-\{node\|short\} \| \{author\|user\} \| \{desc\|strip\|firstline\}}

# hg commit viewer
forhg::log() {
    forhg::inside_work_tree || return 1
    local cmd opts graph files
    files=$(sed --quiet --regexp-extended 's/.* -- (.*)/\1/p' <<< "$*") # extract files parameters for `git show` command
    ###### vvv FIXME vvv ######
    # cmd="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% git show --color=always % -- $files | $forhg_show_pager"
    # cmd="echo {} |grep -Eo '[a-f0-9]+' | head -1 | xargs -I% hg show --color=always % -- $files | $forhg_show_pager"
    cmd="echo {} | head -1 | xargs hg log --rev $files"
    opts="
        $FORHG_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"enter:execute($cmd | LESS='-r' less)\"
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORHG_COPY_CMD:-pbcopy})\"
        $FORHG_LOG_FZF_OPTS
    "
    graph=--graph
    # TODO: if not --graph, add \n to end of forhg_log_format
    [[ $FORHG_LOG_GRAPH_ENABLE == false ]] && graph=
    # eval "git log $graph --color=always --format='$forhg_log_format' $* $forhg_emojify" |
        # FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
    eval "hg log $graph --color=always --template '$forhg_log_format' $* $forhg_emojify" |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
}

# # git diff viewer
# forhg::diff() {
#     forhg::inside_work_tree || return 1
#     local cmd files opts commit repo
#     [[ $# -ne 0 ]] && {
#         if git rev-parse "$1" -- &>/dev/null ; then
#             commit="$1" && files=("${@:2}")
#         else
#             files=("$@")
#         fi
#     }
#     repo="$(git rev-parse --show-toplevel)"
#     cmd="echo {} |sed 's/.*]  //' |xargs -I% git diff --color=always $commit -- '$repo/%' | $forhg_diff_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +m -0 --bind=\"enter:execute($cmd |LESS='-r' less)\"
#         $FORGIT_DIFF_FZF_OPTS
#     "
#     eval "git diff --name-status $commit -- ${files[*]} | sed -E 's/^(.)[[:space:]]+(.*)$/[\1]  \2/'" |
#         FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
# }

# # git add selector
# forhg::add() {
#     forhg::inside_work_tree || return 1
#     # Add files if passed as arguments
#     [[ $# -ne 0 ]] && git add "$@" && git status -su && return
#     local changed unmerged untracked files opts preview extract
#     changed=$(git config --get-color color.status.changed red)
#     unmerged=$(git config --get-color color.status.unmerged red)
#     untracked=$(git config --get-color color.status.untracked red)
#     # NOTE: paths listed by 'git status -su' mixed with quoted and unquoted style
#     # remove indicators | remove original path for rename case | remove surrounding quotes
#     extract="
#         sed 's/^.*]  //' |
#         sed 's/.* -> //' |
#         sed -e 's/^\\\"//' -e 's/\\\"\$//'"
#     preview="
#         file=\$(echo {} | $extract)
#         if (git status -s -- \$file | grep '^??') &>/dev/null; then  # diff with /dev/null for untracked files
#             git diff --color=always --no-index -- /dev/null \$file | $forhg_diff_pager | sed '2 s/added:/untracked:/'
#         else
#             git diff --color=always -- \$file | $forhg_diff_pager
#         fi"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -0 -m --nth 2..,..
#         $FORGIT_ADD_FZF_OPTS
#     "
#     files=$(git -c color.status=always -c status.relativePaths=true status -su |
#         grep -F -e "$changed" -e "$unmerged" -e "$untracked" |
#         sed -E 's/^(..[^[:space:]]*)[[:space:]]+(.*)$/[\1]  \2/' |
#         FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
#         sh -c "$extract")
#     [[ -n "$files" ]] && echo "$files"| tr '\n' '\0' |xargs -0 -I% git add % && git status -su && return
#     echo 'Nothing to add.'
# }

# # git reset HEAD (unstage) selector
# forhg::reset::head() {
#     forhg::inside_work_tree || return 1
#     local cmd files opts
#     cmd="git diff --cached --color=always -- {} | $forhg_diff_pager "
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -m -0
#         $FORGIT_RESET_HEAD_FZF_OPTS
#     "
#     files="$(git diff --cached --name-only --relative | FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")"
#     [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% git reset -q HEAD % && git status --short && return
#     echo 'Nothing to unstage.'
# }

# # git stash viewer
# forhg::stash::show() {
#     forhg::inside_work_tree || return 1
#     local cmd opts
#     cmd="echo {} |cut -d: -f1 |xargs -I% git stash show --color=always --ext-diff % |$forhg_diff_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +s +m -0 --tiebreak=index --bind=\"enter:execute($cmd | LESS='-r' less)\"
#         $FORGIT_STASH_FZF_OPTS
#     "
#     git stash list | FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
# }

# # git clean selector
# forhg::clean() {
#     forhg::inside_work_tree || return 1
#     local files opts
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -m -0
#         $FORGIT_CLEAN_FZF_OPTS
#     "
#     # Note: Postfix '/' in directory path should be removed. Otherwise the directory itself will not be removed.
#     files=$(git clean -xdffn "$@"| sed 's/^Would remove //' | FZF_DEFAULT_OPTS="$opts" fzf |sed 's#/$##')
#     [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% git clean -xdff '%' && git status --short && return
#     echo 'Nothing to clean.'
# }

# forhg::cherry::pick() {
#     local base target preview opts
#     base=$(git branch --show-current)
#     [[ -z $1 ]] && echo "Please specify target branch" && return 1
#     target="$1"
#     preview="echo {1} | xargs -I% git show --color=always % | $forhg_show_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -m -0
#     "
#     git cherry "$base" "$target" --abbrev -v | cut -d ' ' -f2- |
#         FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | cut -d' ' -f1 |
#         xargs -I% git cherry-pick %
# }

# forhg::rebase() {
#     forhg::inside_work_tree || return 1
#     local cmd preview opts graph files commit
#     graph=--graph
#     [[ $FORHG_LOG_GRAPH_ENABLE == false ]] && graph=
#     cmd="git log $graph --color=always --format='$forhg_log_format' $* $forhg_emojify"
#     files=$(sed -nE 's/.* -- (.*)/\1/p' <<< "$*") # extract files parameters for `git show` command
#     preview="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% git show --color=always % -- $files | $forhg_show_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +s +m --tiebreak=index
#         --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORHG_COPY_CMD:-pbcopy})\"
#         $FORGIT_REBASE_FZF_OPTS
#     "
#     commit=$(eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
#         grep -Eo '[a-f0-9]+' | head -1)
#     [[ -n "$commit" ]] && git rebase -i "$commit"
# }

# forhg::fixup() {
#     forhg::inside_work_tree || return 1
#     git diff --cached --quiet && echo 'Nothing to fixup: there are no staged changes.' && return 1
#     local cmd preview opts graph files target_commit prev_commit
#     graph=--graph
#     [[ $FORHG_LOG_GRAPH_ENABLE == false ]] && graph=
#     cmd="git log $graph --color=always --format='$forhg_log_format' $* $forhg_emojify"
#     files=$(sed -nE 's/.* -- (.*)/\1/p' <<< "$*")
#     preview="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% git show --color=always % -- $files | $forhg_show_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +s +m --tiebreak=index
#         --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORHG_COPY_CMD:-pbcopy})\"
#         $FORGIT_FIXUP_FZF_OPTS
#     "
#     target_commit=$(eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
#         grep -Eo '[a-f0-9]+' | head -1)
#     if [[ -n "$target_commit" ]] && git commit --fixup "$target_commit"; then
#         # "$target_commit~" is invalid when the commit is the first commit, but we can use "--root" instead
#         if [[ "$(git rev-parse "$target_commit")" == "$(git rev-list --max-parents=0 HEAD)" ]]; then
#             prev_commit="--root"
#         else
#             prev_commit="$target_commit~"
#         fi
#         # rebase will fail if there are unstaged changes so --autostash is needed to temporarily stash them
#         # GIT_SEQUENCE_EDITOR=: is needed to skip the editor
#         GIT_SEQUENCE_EDITOR=: git rebase --autostash -i --autosquash "$prev_commit"
#     fi
# }

# # git checkout-file selector
# forhg::checkout::file() {
#     forhg::inside_work_tree || return 1
#     [[ $# -ne 0 ]] && { git checkout -- "$*"; return $?; }
#     local cmd files opts
#     cmd="git diff --color=always -- {} | $forhg_diff_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -m -0
#         $FORGIT_CHECKOUT_FILE_FZF_OPTS
#     "
#     files="$(git ls-files --modified "$(git rev-parse --show-toplevel)"| FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")"
#     [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% git checkout %
# }

# # git checkout-branch selector
# forhg::checkout::branch() {
#     forhg::inside_work_tree || return 1
#     [[ $# -ne 0 ]] && { git checkout -b "$*"; return $?; }
#     local cmd preview opts
#     cmd="git branch --color=always --verbose --all --format=\"%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%(refname:short)%(end)\" $forhg_emojify | sed '/^$/d'"
#     preview="git log {} --graph --pretty=format:'$forhg_log_format' --color=always --abbrev-commit --date=relative"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +s +m --tiebreak=index
#         $FORGIT_CHECKOUT_BRANCH_FZF_OPTS
#         "
#     eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | xargs -I% git checkout %
# }

# # git checkout-commit selector
# forhg::checkout::commit() {
#     forhg::inside_work_tree || return 1
#     [[ $# -ne 0 ]] && { git checkout "$*"; return $?; }
#     local cmd opts graph
#     cmd="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% git show --color=always % | $forhg_show_pager"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         +s +m --tiebreak=index
#         --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORHG_COPY_CMD:-pbcopy})\"
#         $FORHG_COMMIT_FZF_OPTS
#     "
#     graph=--graph
#     [[ $FORHG_LOG_GRAPH_ENABLE == false ]] && graph=
#     eval "git log $graph --color=always --format='$forhg_log_format' $forhg_emojify" |
#         FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd" |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% git checkout % --
# }

# # git ignore generator
# export FORGIT_GI_REPO_REMOTE=${FORGIT_GI_REPO_REMOTE:-https://github.com/dvcs/gitignore}
# export FORGIT_GI_REPO_LOCAL="${FORGIT_GI_REPO_LOCAL:-${XDG_CACHE_HOME:-$HOME/.cache}/forhg/gi/repos/dvcs/gitignore}"
# export FORGIT_GI_TEMPLATES=${FORGIT_GI_TEMPLATES:-$FORGIT_GI_REPO_LOCAL/templates}

# forhg::ignore() {
#     [ -d "$FORGIT_GI_REPO_LOCAL" ] || forhg::ignore::update
#     local IFS cmd args opts
#     cmd="$forhg_ignore_pager $FORGIT_GI_TEMPLATES/{2}{,.gitignore} 2>/dev/null"
#     opts="
#         $FORHG_FZF_DEFAULT_OPTS
#         -m --preview-window='right:70%'
#         $FORGIT_IGNORE_FZF_OPTS
#     "
#     # shellcheck disable=SC2206,2207
#     IFS=$'\n' args=($@) && [[ $# -eq 0 ]] && args=($(forhg::ignore::list | nl -nrn -w4 -s'  ' |
#         FZF_DEFAULT_OPTS="$opts" fzf --preview="eval $cmd" | awk '{print $2}'))
#     [ ${#args[@]} -eq 0 ] && return 1
#     # shellcheck disable=SC2068
#     forhg::ignore::get ${args[@]}
# }
# forhg::ignore::update() {
#     if [[ -d "$FORGIT_GI_REPO_LOCAL" ]]; then
#         forhg::info 'Updating gitignore repo...'
#         (cd "$FORGIT_GI_REPO_LOCAL" && git pull --no-rebase --ff) || return 1
#     else
#         forhg::info 'Initializing gitignore repo...'
#         git clone --depth=1 "$FORGIT_GI_REPO_REMOTE" "$FORGIT_GI_REPO_LOCAL"
#     fi
# }
# forhg::ignore::get() {
#     local item filename header
#     for item in "$@"; do
#         if filename=$(find -L "$FORGIT_GI_TEMPLATES" -type f \( -iname "${item}.gitignore" -o -iname "${item}" \) -print -quit); then
#             [[ -z "$filename" ]] && forhg::warn "No gitignore template found for '$item'." && continue
#             header="${filename##*/}" && header="${header%.gitignore}"
#             echo "### $header" && cat "$filename" && echo
#         fi
#     done
# }
# forhg::ignore::list() {
#     find "$FORGIT_GI_TEMPLATES" -print |sed -e 's#.gitignore$##' -e 's#.*/##' | sort -fu
# }
# forhg::ignore::clean() {
#     setopt localoptions rmstarsilent
#     [[ -d "$FORGIT_GI_REPO_LOCAL" ]] && rm -rf "$FORGIT_GI_REPO_LOCAL"
# }

FORHG_FZF_DEFAULT_OPTS="
$FZF_DEFAULT_OPTS
--ansi
--height='80%'
--bind='alt-k:preview-up,alt-p:preview-up'
--bind='alt-j:preview-down,alt-n:preview-down'
--bind='ctrl-r:toggle-all'
--bind='ctrl-s:toggle-sort'
--bind='?:toggle-preview'
--bind='alt-w:toggle-preview-wrap'
--preview-window='right:60%'
+1
$FORHG_FZF_DEFAULT_OPTS
"

# register aliases
# shellcheck disable=SC2139
if [[ -z "$FORGIT_NO_ALIASES" ]]; then
    alias "${forhg_add:-ga}"='forhg::add'
    alias "${forhg_reset_head:-grh}"='forhg::reset::head'
    alias "${forhg_log:-glo}"='forhg::log'
    alias "${forhg_diff:-gd}"='forhg::diff'
    alias "${forhg_ignore:-gi}"='forhg::ignore'
    alias "${forhg_checkout_file:-gcf}"='forhg::checkout::file'
    alias "${forhg_checkout_branch:-gcb}"='forhg::checkout::branch'
    alias "${forhg_checkout_commit:-gco}"='forhg::checkout::commit'
    alias "${forhg_clean:-gclean}"='forhg::clean'
    alias "${forhg_stash_show:-gss}"='forhg::stash::show'
    alias "${forhg_cherry_pick:-gcp}"='forhg::cherry::pick'
    alias "${forhg_rebase:-grb}"='forhg::rebase'
    alias "${forhg_fixup:-gfu}"='forhg::fixup'
fi
