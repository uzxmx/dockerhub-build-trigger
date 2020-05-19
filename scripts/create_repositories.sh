#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

cat "$rootdir/projects.txt" | awk '{print $1}' | xargs utils create-repos -u mirror4gcr
