#!/bin/sh

NOTE() {
  echo '#' "$@" 1>&2
}

ERR() {
  echo '!' "$@" 1>&2
  exit 1
}

noargs() {
  if [ "$1" -gt 0 ]; then
    ERR 'Got arguments when none where expected'
  fi
}

# Commands
# ======================================================================


## help
## ----

ws_usage_help() {
  cat 1>&2 <<EOF
Usage: $* <cmd>

Prints the usage text for a command.
This is the same as running '$1 <cmd> -h'.
EOF
}

ws_cmd_help() {
  if [ -n "${1+x}" ] && [ -z "$(command -v "ws_cmd_${1}" 2>/dev/null)" ]; then
    echo "Unrecognized command: '$1'" 1>&2
    exit 1
  fi
  check_help "${1-main}" -h
}


ws_usage_init() {
  cat 1>&2 <<EOF
Usage: $*

Initialize the workspace by creating the void-packages directory.
If run again, this will fetch and update the void-packages clone.
EOF
}

ws_cmd_init() {
  noargs $#
  NOTE 'Fetching void-packages'
  if [ -d void-packages ] && [ "${pull:-1}" = 1 ]; then
    (
    cd "$ws_pkgsrc"
    git fetch origin master
    git checkout --force master
    git reset --hard origin/master
    )
  elif ! [ -d "$ws_pkgsrc" ]; then
    git clone https://github.com/void-linux/void-packages.git "$ws_pkgsrc"
  fi
}


each_pkg() {
  find "$ws_exesrc/srcpkgs" -mindepth 2 -maxdepth 2 -type f -name template |
    fex /-2 |
    xargs -L1 -I{pkg} "$@"
}

create_binds() {
  each_pkg mkdir "$ws_pkgsrc/srcpkgs/{pkg}"
  each_pkg bindfs --no-allow-other "$ws_exesrc/srcpkgs/{pkg}" "$ws_pkgsrc/srcpkgs/{pkg}"
}

clean_binds() {
  each_pkg fusermount -u "$ws_pkgsrc/srcpkgs/{pkg}"
  each_pkg rm -r "$ws_pkgsrc/srcpkgs/{pkg}"
}

ws_usage_src() {
  cat 1>&2 <<EOF
Usage: $* [args...]

Run xbps-src with the given arguments.
EOF
}

ws_cmd_src() {
  ws_cmd_run ./xbps-src "$@"
}

on_all_packages() {
  echo "$@" | fgrep '{pkg}'
}

ws_usage_run() {
  cat 1>&2 <<EOF
Usage: $* <cmd> [args...]

Run <cmd> with the given arguments from the void-packages workspace.
EOF
}

ws_cmd_run() {
  create_binds
  if on_all_packages "$@"; then
    (cd "$ws_pkgsrc" && each_pkg "$@")
  else
    (cd "$ws_pkgsrc" && "$@")
  fi
  local ec=$?
  clean_binds
  return $ec
}

# check_help CMD ARG1
#
# Checks if ARG1 is -h, -help, or --help and prints CMD's usage if it
# is. The program then exits with status 2.
#
# Used as check_help CMD "$1" primarily, except in the help command.
check_help() {
  if [ "$2" = -h ] || [ "$2" = -help ] || [ "$2" = --help ]; then
    "ws_usage_${1}" "$(basename "$0")" "$1"
    exit 2
  fi
}

ws_usage_main() {
  cat 1>&2 <<EOF
Usage: $1 <cmd> [options]

Commands
  help       Print help text for this program or a command.
  init       Initialize workspace.
  src        Run xbps-src with package templates bind-mounted.
  run        Run an arbitrary command in the void-packages workspace.

Any unrecognized command is treated as an xbps-src command and is
equivalent to running 'src' with the same arguments.

If a command passed to src or run contains the string '{pkg}', it is
applied to all packages in the parent srcpkgs.
EOF
}


main() {
  mode="${1-help}"
  [ $# -eq 0 ] || shift

  case "$mode" in
  -h|--help)
    ws_cmd_help
    ;;
  esac

  if [ -z "$(command -v "ws_cmd_${mode}" 2>/dev/null)" ]; then
    ws_cmd_run ./xbps-src "${mode}" "$@"
    exit $?
  fi

  check_help "$mode" "$1"
  "ws_cmd_${mode}" "$@"
}

cd "$(dirname "$0")"
export ws_exesrc="$(pwd)"
export ws_pkgsrc="${ws_exesrc}/void-packages"

main "$@"
