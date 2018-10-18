#!/bin/bash

set -e

source cluster/common.sh

pushd $kubevirt_src > /dev/null
cluster/cli.sh "$@"
popd > /dev/null
