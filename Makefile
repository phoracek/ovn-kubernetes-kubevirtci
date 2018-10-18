all: cluster-up cluster-sync-kubevirt cluster-sync-ovn

cluster-up:
	./cluster/up.sh

cluster-down:
	./cluster/down.sh

cluster-sync-kubevirt:
	./cluster/sync-kubevirt.sh

cluster-sync-ovn:
	./cluster/sync-ovn.sh

.PHONY: build cluster-up cluster-down cluster-sync-kubevirt cluster-sync-ovn
