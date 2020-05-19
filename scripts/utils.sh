#!/usr/bin/env bash

rootdir="$(dirname $BASH_SOURCE)/.."

info() {
  echo "$@"
}

error() {
  echo "$@"
}

abort() {
  error "$@"
  exit 1
}

get_project() {
  name="$1"
  cat "$rootdir/projects.txt" | grep "^$name "
}

get_registry_type() {
  project="$1"
  echo "$project" | awk '{print $2}'
}

get_registry() {
  registry_type="$(get_registry_type "$1")"
  case "$registry_type" in
    gcr)
      echo "gcr.io"
      ;;
    *)
      echo "Unsupported registry: $registry_type"
      exit 1
      ;;
  esac
}

get_namespace() {
  project="$1"
  echo "$project" | awk '{print $3}'
}

get_gcr_image_tags() {
  local name=$1
  local namespace=$2
  curl -s https://gcr.io/v2/$namespace/$name/tags/list | jq -r '.tags[]'
}
