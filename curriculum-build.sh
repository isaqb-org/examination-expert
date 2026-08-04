#!/bin/sh
# Build the iSAQB curricula of this repo via the prebuilt builder image. Renders into ./build.
#   ./curriculum-build.sh                                        # all documents x languages x formats
#   ./curriculum-build.sh pdf DE                                 # single format + language, all documents
#   ./curriculum-build.sh pdf DE REMARKS                         # + suffix tag
#   CURRICULUM_FILE=examination-criteria ./curriculum-build.sh    # one document only
#   ./curriculum-build.sh clean                                  # remove build/ outputs
#
# The builder image renders one AsciiDoc root per run, so this script runs the
# container once per entry in CURRICULUM_FILES (see build.config).
set -eu

IMAGE="ghcr.io/isaqb-org/curriculum-builder:2026.3-rev3"
DIGEST="sha256:47fb269758499d2b0bdaf4690817f4ea2460c1a7ccd5e34da77c86674f0bf691"

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

ref="$IMAGE"
[ -n "$DIGEST" ] && ref="${IMAGE}@${DIGEST}"

# Default to empty without clobbering values already in the environment — build.config
# uses `: "${KEY:=value}"`, so an environment value keeps winning over the config.
: "${CURRICULUM_FILE:=}"
: "${CURRICULUM_FILES:=}"
: "${LANGUAGES:=}"
: "${SUFFIX_TAGS:=}"
: "${PREPRESS:=}"
if [ -f "$REPO_ROOT/build.config" ]; then
  # shellcheck disable=SC1091
  . "$REPO_ROOT/build.config"
fi

# An explicit CURRICULUM_FILE wins over the configured list.
files=${CURRICULUM_FILE:-$CURRICULUM_FILES}

docker pull "$ref" >/dev/null

run_builder() {
  curriculum_file=$1
  shift
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$REPO_ROOT:/project" \
    -w /project \
    -e "CURRICULUM_FILE=${curriculum_file}" \
    -e "LANGUAGES=${LANGUAGES}" \
    -e "SUFFIX_TAGS=${SUFFIX_TAGS}" \
    -e "PREPRESS=${PREPRESS}" \
    -e "RELEASE_VERSION=${RELEASE_VERSION:-LocalBuild}" \
    "$ref" "$@"
}

# "clean" needs no curriculum file and must not run once per document.
if [ "${1:-}" = "clean" ]; then
  run_builder "" "$@"
  exit 0
fi

# Empty list: run once so the image emits its own "CURRICULUM_FILE not set" error.
if [ -z "$files" ]; then
  run_builder "" "$@"
  exit 0
fi

for curriculum in $files; do
  echo "=== $curriculum ==="
  run_builder "$curriculum" "$@"
done

echo "Done. Output in $REPO_ROOT/build/"
