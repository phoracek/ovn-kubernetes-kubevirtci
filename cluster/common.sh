kubevirt_src=${KUBEVIRT_SRC:-$GOPATH/src/kubevirt.io/kubevirt}
ovn_src=${OVN_SRC:-$GOPATH/src/github.com/openvswitch/ovn-kubernetes}

num_nodes=${NUM_NODES:-1}

ovn_primary=${OVN_PRIMARY:-1} # or 0
provider=${PROVIDER:-kubernetes} # or openshift

if [ "$provider" = "kubernetes" ]; then
    kubevirt_provider="k8s-multus-1.11.1"
elif [ "$provider" = "openshift" ]; then
    kubevirt_provider="os-3.10.0-multus"
else
    exit 1
fi

export KUBEVIRT_NUM_NODES=$num_nodes
export KUBEVIRT_PROVIDER=$kubevirt_provider
export KUBEVIRT_DIR=$kubevirt_src
