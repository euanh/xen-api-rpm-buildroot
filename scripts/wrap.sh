#!/bin/bash

# Wrapper for build commands - runs the build command and pipes its output through ts
# This will not be needed with GNU Make 4.0

set -o pipefail
shift
echo "$@" | ts $LOGPREFIX
unbuffer bash -c "$@" | ts $LOGPREFIX
