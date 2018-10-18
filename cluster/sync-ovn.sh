#!/bin/bash

set -e

source cluster/common.sh

# If OVN is not to be used, stop here
if [[ $ovn_primary -eq 0 ]]; then
    exit 0
fi

# Remove existing setup
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/ovn-namespace.yaml
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/ovn-config.yaml
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/ovn-policy.yaml
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/sdn-ovs.yaml
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/ovnkube-master.yaml
cluster/kubectl.sh delete --ignore-not-found -f $(pwd)/cluster/manifests/ovnkube.yaml
cluster/kubectl.sh delete --ignore-not-found -n ovn-kubernetes ds netplugin-setup

# Wait for all resources to be removed
until [[ $(cluster/kubectl.sh get --ignore-not-found -f $(pwd)/cluster/manifests/sdn-ovs.yaml 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done
until [[ $(cluster/kubectl.sh get --ignore-not-found -f $(pwd)/cluster/manifests/ovnkube-master.yaml 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done
until [[ $(cluster/kubectl.sh get --ignore-not-found -f $(pwd)/cluster/manifests/ovnkube.yaml 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done
until [[ $(cluster/kubectl.sh get --ignore-not-found -n ovn-kubernetes ds netplugin-setup 2>&1 | wc -l) -eq 0 ]]; do sleep 1; done

# Build OVN daemon set image and push it to local cluster
pushd $ovn_src
docker build -f Dockerfile.centos -t ovn-daemonset .
popd
registry=localhost:$(cluster/cli.sh ports registry | tr -d '\r')
docker tag ovn-daemonset $registry/ovn-daemonset:latest
docker push $registry/ovn-daemonset:latest

# Deploy OVN plugin
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/ovn-namespace.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/ovn-config.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/ovn-policy.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/sdn-ovs.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/ovnkube-master.yaml
cluster/kubectl.sh create -f $(pwd)/cluster/manifests/ovnkube.yaml

# Wait for all resources to be deployed
until [[ $(cluster/kubectl.sh get --no-headers -f $(pwd)/cluster/manifests/sdn-ovs.yaml 2>&1 | awk '{ if ($3 == $4) print "1"; else print "0"}') -ne 0 ]]; do sleep 1; done
until [[ $(cluster/kubectl.sh get --no-headers -f $(pwd)/cluster/manifests/ovnkube-master.yaml 2>&1 | awk '{ if ($3 == $4) print "1"; else print "0"}') -ne 0 ]]; do sleep 1; done
until [[ $(cluster/kubectl.sh get --no-headers -f $(pwd)/cluster/manifests/ovnkube.yaml 2>&1 | awk '{ if ($3 == $4) print "1"; else print "0"}') -ne 0 ]]; do sleep 1; done

# Configure network plugins
config_command=''
if [[ $ovn_primary -ne 0 ]]; then
    config_command+='
          cat <<EOF > /etc/cni/net.d/70-multus.conf;
          {
            "name": "multus-cni-network",
            "type": "multus",
            "delegates": [
              {"cniVersion": "0.3.1", "name": "ovn-kubernetes", "type": "ovn-k8s-cni-overlay", "ipam": {}, "dns": {}}
            ],
            "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig"
          }
          EOF
'
fi
config_command+='
           mv /etc/cni/net.d/70-multus.conf /etc/cni/net.d/00-multus.conf;
           sleep infinity
'

cat <<EOF | cluster/kubectl.sh create -f -
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: netplugin-setup
  namespace: ovn-kubernetes
spec:
  selector:
    matchLabels:
      name: netplugin-setup
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: netplugin-setup
        component: network
        type: infra
        openshift.io/component: network
    spec:
      serviceAccountName: ovn
      hostNetwork: true
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: ovnkube-master
        image: fedora
        command:
        - /bin/bash
        - -x
        - -c
        - |
$config_command
        securityContext:
          runAsUser: 0
          privileged: true
        volumeMounts:
        - mountPath: /etc/cni/net.d
          name: host-etc-cni-netd
        resources:
          requests:
            cpu: 100m
            memory: 300Mi
        lifecycle:
      nodeSelector:
        beta.kubernetes.io/os: "linux"
      volumes:
      - name: host-etc-cni-netd
        hostPath:
          path: /etc/cni/net.d
EOF

until [[ $(cluster/kubectl.sh -n ovn-kubernetes get --no-headers daemonset 2>&1 | grep netplugin-setup | awk '{ if ($3 == $4) print "1"; else print "0"}') -ne 0 ]]; do sleep 1; done
