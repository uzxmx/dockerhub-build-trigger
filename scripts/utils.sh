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
  local project="$1"
  echo "$project" | awk '{print $2}'
}

get_registry() {
  local registry_type="$(get_registry_type "$1")"
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
  local project="$1"
  echo "$project" | awk '{print $3}'
}

get_gcr_image_tags() {
  local name=$1
  local namespace=$2
  curl -s https://gcr.io/v2/$namespace/$name/tags/list | jq -r '.tags[]'
}

get_docker_repo() {
  local name="$1"
  local project="$2"
  local registry_type="$(get_registry_type "$project")"
  local namespace="$(get_namespace "$project")"

  case "$registry_type" in
    gcr)
      echo "gcr.io/$namespace/$name"
      ;;
    github)
      case "$namespace" in
        kubernetes/kubernetes)
          echo "k8s.gcr.io/$name"
          ;;
        *)
          echo "Unsupported namespace: $namespace"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unsupported registry: $registry_type"
      exit 1
      ;;
  esac
}
