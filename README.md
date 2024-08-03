# Create K8s cluster using kubeadm in Ubuntu 24.04 and RHEL9

Use the shell scripts in this repo to provision Kubernetes cluster on Ubuntu and RHEL servers.

Note: these scripts are a set of standard shell commands to create a k8s cluster that are to be executed in specific order. No complex logic or conditions are added to the script.

### Scripts are tested on following server versions.

Ubuntu server 24.04

RHEL 9.4

Clusters created by the scripts uses cri-o as the container runtime (CRI). No networking add-on is included in the script.

Follow the documentation to install desired networking add-on of your choice.

[Networking and network policy](https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy)
