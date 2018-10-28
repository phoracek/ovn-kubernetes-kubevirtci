# OVN Kubernetes on kubevirtci

## Local cluster usage

Configurable variables and their defaults. If some of them was changed, whole
cluster must be destroyed and recreated.

```shell
export KUBEVIRT_SRC=$GOPATH/src/kubevirt.io/kubevirt
export OVN_SRC=$GOPATH/src/github.com/openvswitch/ovn-kubernetes
export NUM_NODES=1
export OVN_PRIMARY=1 # OVN should replace default network plugin, use 0 to disable
export PROVIDER=kubernetes # or openshift
```

Deploy local cluster.

```shell
make cluster-up
```

Build KubeVirt from local sources and deploy it on the cluster. Can be done
repeatedly on single cluster deployment.

```shell
make cluster-sync-kubevirt
```

Build OVN Kubernetes from local sources and deploy it on the cluster. Can be
done repeatedly on single cluster deployment.

```shell
make cluster-sync-ovn
```

Use `kubectl` on the local cluster. Please note, that path to any file must be
absolute.

```shell
cluster/kubectl.sh get pods
cluster/kubectl.sh create -f $(pwd)/cluster/examples/pod-on-default.yaml
```

Collect to a node via ssh.

```shell
cluster/cli.sh ssh node01
```

Destroy cluster.

```shell
make cluster-down
```

## Examples

### Create simple pod connected to default network

```shell
# Create a Pod
cluster/kubectl.sh create -f $(pwd)/cluster/examples/pod-on-default.yaml

# Verify that interface was added to the Pod
cluster/kubectl.sh exec on-default ip a
```

### Create a pod connected to secondary OVN network

```shell
# Create OVN LS
ovnkube_master=$(./cluster/kubectl.sh -n ovn-kubernetes get pods | grep ovnkube-master | awk '{print $1}')
cluster/kubectl.sh -n ovn-kubernetes exec $ovnkube_master ovn-nbctl ls-add green
cluster/kubectl.sh -n ovn-kubernetes exec $ovnkube_master ovn-nbctl set Logical_Switch green other_config:subnet=192.168.1.0/24

# Create networks and connect Pod to them
cluster/kubectl.sh create -f $(pwd)/cluster/examples/net-green.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/examples/pod-on-green.yaml

# Verify that LSP was created
cluster/kubectl.sh -n ovn-kubernetes exec $ovnkube_master ovn-nbctl show

# Verify that interface was added to the Pod
cluster/kubectl.sh exec on-green ip a
```
