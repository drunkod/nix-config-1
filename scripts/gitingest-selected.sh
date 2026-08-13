#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: gitingest-selected.sh <repository> <path-list> <output-file>" >&2
  exit 2
fi

repo_root=$(git -C "$1" rev-parse --show-toplevel)
list_file=$2
output_file=$3
packet_root=$(mktemp -d "${TMPDIR:-/tmp}/gitingest-selected.XXXXXX")

cleanup() {
  rm -rf -- "$packet_root"
}
trap cleanup EXIT HUP INT TERM

copied=0
while IFS= read -r path || [ -n "$path" ]; do
  [ -n "$path" ] || continue

  case "$path" in
    /*|../*|*/../*|*/..|..)
      echo "STOP: path must be repository-relative: $path" >&2
      exit 1
      ;;
  esac

  source_path=$repo_root/$path
  [ -L "$source_path" ] && {
    echo "STOP: symlinks are not supported: $path" >&2
    exit 1
  }
  [ -f "$source_path" ] || continue

  target_path=$packet_root/$path
  mkdir -p -- "$(dirname -- "$target_path")"
  cp -- "$source_path" "$target_path"
  copied=$((copied + 1))
done < "$list_file"

if [ "$copied" -eq 0 ]; then
  echo "STOP: no current files to digest" >&2
  exit 1
fi

gitingest "$packet_root" --output "$output_file"
