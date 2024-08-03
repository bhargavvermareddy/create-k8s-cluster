# Run following commands in both master and worker node(s)
# https://github.com/cri-o/packaging/blob/main/README.md#usage

set +e

set +x

# Export environment variables for Kubernetes and cri-o runtime
export KUBERNETES_VERSION=v1.30 && \
export CRIO_VERSION=v1.30

echo "==> Disabling Swap"
sudo swapoff -a # Disabling swap
sudo sed -e '/swap/s/^/#/g' -i /etc/fstab # Disabling swap permanently

# setting sexliunx to Permissive mode
echo "==> Disabling SELinux"
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


# opening required ports for k8s
# 6443/tcp   # Kubernetes API server
# 2379-2380  # etcd server client API
# 10250/tcp  # Kubelet API
# 10251/tcp  # kube-scheduler
# 10252/tcp  # kube-controller-manager
# 10255/tcp  # Read-only Kubelet API
# 5473/tcp   # ClusterControlPlaneConfig API
echo "==> Opening required ports for K8s cluster"
sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=2379-2380/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=10250/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=10251/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=10252/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=10255/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port=5473/tcp

# open the following port on master node if you opt to install Calico CNI
# sudo firewall-cmd --zone=public --permanent --add-port=179/tcp

echo "==> Reloading firewall-cmd"
sudo firewall-cmd --reload

echo "==> Applying modprobes"
sudo modprobe br_netfilter && \
sudo modprobe ip_vs && \
sudo modprobe ip_vs_rr && \
sudo modprobe ip_vs_wrr && \
sudo modprobe ip_vs_sh && \
sudo modprobe overlay


cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF

cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

# Add the Kubernetes repository
echo "==> Adding Kubernetes repository"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF

# Add the CRI-O repository
echo "==> Adding cri-o repository"
cat <<EOF | sudo tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF

# Install the packages
echo "==> Installing the required packages"
sudo dnf install -y container-selinux
sudo dnf install -y cri-o kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo dnf mark install cri-o kubelet kubeadm kubectl # use 'dnf mark remove' to remove the mark

# Enabling kubelet and crio to run even after node restarts
echo "==> Enabling and starting kubelet and cri-o services using systemctl"
sudo systemctl enable kubelet && sudo systemctl start kubelet
sudo systemctl enable crio && sudo systemctl start crio

### END of commands for both master and worker node(s) ###

# Run the following commands only in master node(s)

echo "==> Pulling necessary images for starting k8s cluster"
sudo kubeadm config images pull # optional command, because 'kubeadm init' command will pull images

echo "==> Initializing the K8s cluster using kubeadm init command"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<master-node-ip/loadbalancer-ip>

# By default, your cluster will not schedule Pods on the control plane nodes for security reasons. If you want to be able to schedule Pods on the control plane nodes, for example for a single machine Kubernetes cluster, run:

# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
