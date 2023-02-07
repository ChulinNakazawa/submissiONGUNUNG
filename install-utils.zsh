#!/bin/zsh -e

typeset -A ubuntu_pkg
ubuntu_pkg[pcre]=libpcre3-dev
ubuntu_pkg[zlib]=libz-dev
ubuntu_pkg[readline]=libreadline-dev
ubuntu_pkg[ncurses]=ncurses-dev
ubuntu_pkg[sqlite]=libsqlite3-dev
ubuntu_pkg[uuid]=uuid-dev

# versions

# prepare

DOWNLOAD=/tmp
SRC=~/.local/src

mkdir -p $DOWNLOAD
mkdir -p $SRC
cd $SRC

# zsh config

setopt extended_glob       # expand *(xx)
setopt equals              # expand =program
setopt magic_equal_subst   # expand xx=~yy

# functions

info() {
  echo "\e[1;34m++++ $*\e[m"
}

error() {
  echo "\e[1;31m!!! $*\e[m"
  exit 1
}

bin() {
  [[ -n ${commands[$1]} ]]
}

# prepend PATH

[[ $PATH =~ ~/.local/bin ]] && PATH=~/.local/bin:$PATH

# download

clone() {
    [[ -d $2 ]] || git clone $1 $2
}

clone https://gi