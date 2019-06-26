#!/bin/sh

if [ -r conf ]; then
  . ./conf
  export PKGDIR PKGKEY PKGSIGNATURE
fi

# TODO: Add clean-up hook functions via conf?

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

fetch_repo() {
  local upstream=master
  local pull=1
  local opt=
  while getopts ":u:P:" opt; do
    case "${opt}" in
    u) upstream="${OPTARG}";;
    P) pull=0;;
    :) ERR "fetch_repo: unrecognized argument: ${opt}";;
    esac
  done
  shift $((OPTIND-1))
  if [ $# -lt 1 ]; then
    ERR 'fetch_repo: no repo given'
  elif [ $# -gt 2 ]; then
    ERR 'fetch_repo: too many arguments'
  fi
  local repo="$1"
  local dir="${2:-$(basename "${repo}" .git)}"
  if [ -d "$dir" ] && [ "${pull}" = 1 ]; then
    (
    cd "$dir"
    git fetch origin "$upstream"
    git checkout --force "$upstream"
    git reset --hard "origin/${upstream}"
    )
  elif ! [ -d "$dir" ]; then
    git clone --branch="$upstream" "$repo" "$dir"
  fi
}

ws_cmd_init() {
  noargs $#
  NOTE 'Fetching void-packages'
  fetch_repo 'https://github.com/void-linux/void-packages.git' "$ws_pkgsrc"
  NOTE 'Fetching xtools'
  fetch_repo 'https://github.com/chneukirchen/xtools.git' "$ws_xtsrc"
}

all_pkg() {
  find "${ws_pkgnew}/srcpkgs" -mindepth 2 -maxdepth 2 -type f -name template |
    fex /-2 |
    sort
}

each_pkg() {
   all_pkg | xargs -t -L1 -I{pkg} "$@"
}

create_binds() {
  if [ -d "${ws_dir}" ]; then
    if [ ! -e "${ws_dir}" ] && ! rm -d "$ws_dir"; then
      ERR 'Workspace already exists but is not empty and is not recognized'
    fi
    return 0
  fi
  mkdir "$ws_dir"
  if ! mergerfs "${ws_pkgnew}:${ws_pkgsrc}" "$ws_dir"; then
    rm -d "$ws_dir"
    ERR 'Unable to create workspace'
  fi
}

clean_binds() {
  if [ ! -d .work ]; then
    return 0
  fi
  fusermount -u .work ||
    ERR 'Unable to unmount workspace'
  rm -d .work
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


ws_usage_binds() {
  cat 1>&2 <<EOF
Usage: $* {create|rm}

Create, or remove, the .work directory.
EOF
}

ws_cmd_binds() {
  cmd="$1"
  case "$cmd" in
  create|clean)
    shift
    noargs $#
    "${cmd}_binds";;
  *)
    ERR "Unexpected command: $1";;
  esac
}

on_all_packages() {
  echo "$@" | fgrep -q '{pkg}'
}

ws_usage_run() {
  cat 1>&2 <<EOF
Usage: $* <cmd> [args...]

Run <cmd> with the given arguments from the void-packages workspace.
EOF
}

ws_cmd_run() {
  create_binds
  trap 'clean_binds' EXIT
  if on_all_packages "$@"; then
    (cd "$ws_dir" && each_pkg "$@")
  else
    (cd "$ws_dir" && "$@")
  fi
  local ec=$?
  return $ec
}

ws_usage_sh() {
  cat 1>&2 <<EOF
Usage: $* <cmd>

Run <cmd> as a shell script from the void-packages workspace.
EOF
}

ws_cmd_sh() {
  create_binds
  trap 'clean_binds' EXIT
  if on_all_packages "$@"; then
    (cd "$ws_dir" && each_pkg sh -c "$*")
  else
    (cd "$ws_dir" && sh -c "$*")
  fi
  local ec=$?
  return $ec
}

ws_usage_export() {
  cat 1>&2 <<EOF
Usage: $* <pkg...>

Copy one or more packages to the set PKGDIR.

If PKGSIGNATURE and PKGKEY are also set to the signature and path to the
private key, respectively, then the package and repository metadata are
also signed.
EOF
}

ws_cmd_export() {
  if [ -z "$PKGDIR" ]; then
    ERR "PKGDIR must be set before running export"
  fi

  local arch=
  local targetarch=
  while getopts ":a:" opt; do
    case "$opt" in
    a) arch="${OPTARG}";;
    :) ERR "export: unrecognized argument: ${opt}";;
    esac
  done
  shift $((OPTIND-1))

  create_binds
  trap 'clean_binds' EXIT

  (
  cd "$ws_dir"

  if [ -z "$arch" ]; then
    arch="$(./xbps-src show-var XBPS_ARCH)"
  fi

  local pkgname=
  local version=
  local revision=

  for pkg; do
    (
    eval "$(
      ./xbps-src show "$pkg" |
      awk -F"\t" '
        ($1 ~ /^(pkgname|version|revision|archs):$/) {
          sub(/:[ \t]*/, "=", $0)
          print "pkg_" $0
        }'
      )"
    if [ "$pkg_archs" = noarch ]; then
      targetarch="${targetarch:-noarch}"
    fi
    targetarch="${targetarch:-$arch}"

    pkgfile="${pkg_pkgname}-${pkg_version}_${pkg_revision}.${targetarch}.xbps"
    pkgpath="hostdir/binpkgs/$pkgfile"
    if [ ! -r "$pkgpath" ]; then
      NOTE "Package missing: $pkgpath; building..."
      if ! ./xbps-src pkg -a "$arch" "$pkg"; then
        ERR "Failed to build package: $pkg"
      fi
    fi
    NOTE "Copying $pkgfile"
    if ! install -m644 "$pkgpath" "$PKGDIR/"; then
      ERR "Unable to copy package: $pkgfile"
    fi
    if ! (
      set -e
      cd "$PKGDIR"
      xbps-rindex -v -a "$pkgfile"
      if [ -n "$PKGKEY" ] && [ -n "$PKGSIGNATURE" ]; then
        NOTE "Signing package: $pkgfile"
        xbps-rindex -v --signedby "$PKGSIGNATURE" --privkey "$PKGKEY" --sign-pkg "$pkgfile"
        xbps-rindex -v --signedby "$PKGSIGNATURE" --privkey "$PKGKEY" --sign .
      fi
    ); then
      ERR "Unable to index package: $pkgfile"
    fi
    )
  done
  )
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
  export     Export a package to the local repository.
  src        Run xbps-src with package templates bind-mounted.
  run        Run an arbitrary command in the void-packages workspace.
  sh         Run an shell string in the void-packages workspace.
  binds      Create or clean package bindings.

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
  else
    check_help "$mode" "$1"
    "ws_cmd_${mode}" "$@"
  fi
}

cd "$(dirname "$0")"
export ws_exesrc="$(pwd)"
export ws_dir="${ws_exesrc}/.work"
export ws_pkgnew="${ws_exesrc}/root"
export ws_pkgsrc="${ws_exesrc}/void-packages"
export ws_xtsrc="${ws_exesrc}/xtools"

export PATH="${ws_xtsrc}:$PATH"

main "$@"
