# Run following commands in both master and worker node(s)
# https://github.com/cri-o/packaging/blob/main/README.md#usage

# Export environment variables for Kubernetes and cri-o runtime
export KUBERNETES_VERSION=v1.30 && \
export CRIO_VERSION=v1.30


sudo swapoff -a # Disabling swap
sed -e '/swap/s/^/#/g' -i /etc/fstab # Disabling swap permanently

# opening required ports for k8s
sudo ufw allow 6443/tcp && \        # Kubernetes API server
sudo ufw allow 2379:2380/tcp && \   # etcd server client API
sudo ufw allow 10250/tcp && \   	# Kubelet API
sudo ufw allow 10251/tcp && \       # kube-scheduler
sudo ufw allow 10252/tcp && \       # kube-controller-manager
sudo ufw allow 10255/tcp && \       # Read-only Kubelet API
sudo ufw allow 5473/tcp             # ClusterControlPlaneConfig API

# sudo iptables -L -n

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
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add the CRI-O repository
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# Install the packages
sudo apt update
sudo apt install -y software-properties-common curl
sudo apt install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold cri-o kubelet kubeadm kubectl
sudo apt-mark showhold

# Enabling kubelet and crio to run even after node restarts
sudo systemctl enable kubelet && sudo systemctl start kubelet
sudo systemctl enable crio && sudo systemctl start crio

### END of commands for both master and worker node(s) ###

# Create cluster with kubeadm, run following command only on your master node(s)

sudo kubeadm config images pull # optional command, because 'kubeadm init' command will pull images

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<master-node-ip/loadbalancer-ip>

# By default, your cluster will not schedule Pods on the control plane nodes for security reasons. If you want to be able to schedule Pods on the control plane nodes, for example for a single machine Kubernetes cluster, run:

# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
