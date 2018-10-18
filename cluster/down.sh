#!/bin/bash

set -e

source cluster/common.sh

pushd $kubevirt_src
make cluster-down
popd
