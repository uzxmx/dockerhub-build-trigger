#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

version_required=false
source "$rootdir/scripts/parse_project.sh"

case "$registry_type" in
  gcr)
    get_gcr_image_tags $name $namespace
    ;;
  *)
    abort "Unsupported registry: $registry_type"
    ;;
esac
