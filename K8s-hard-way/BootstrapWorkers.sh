LATEST_K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)

while getopts ":i:l:" opt; do
  case $opt in
    i) NODE_ID="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

init_setup(){
  # Install the OS dependencies:
  sudo apt-get update
  sudo apt full-upgrade -y
  sudo apt-get -y install socat conntrack ipset

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 OS dependencies installed \e[0m"

  # Disable Swap
  sudo swapon --show
  sudo swapoff -a

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Swap disabled \e[0m"
}

# Download and Install Worker Binaries
download_binaries(){
  wget --https-only --timestamping \
    https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.26.0/crictl-v1.26.0-linux-amd64.tar.gz \
    https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64 \
    https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz \
    https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz \
    https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kube-proxy \
    https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kubelet

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Worker binaries downloaded \e[0m"
}
# Install the Containerd Binaries
install_containerd(){
  mkdir -p containerd
  tar -xvf crictl-v1.26.0-linux-amd64.tar.gz
  tar -xvf containerd-1.4.4-linux-amd64.tar.gz -C containerd
  sudo tar -xvf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/
  sudo mv containerd/bin/* /bin/
}

setup_containerd(){
  sudo mv runc.amd64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc 
  sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
}

configure_cni(){
  # Configure CNI Networking
  sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

  sudo mkdir -p /etc/containerd/
  sudo mv config.toml /etc/containerd/config.toml
  sudo mv containerd.service /etc/systemd/system/containerd.service

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 CNI Networking configured \e[0m"
}

# Configure the Kubelet
setup_kubelet(){

  sudo mv ${NODE_ID}-key.pem ${NODE_ID}.pem /var/lib/kubelet/
  sudo mv ${NODE_ID}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/
  sudo mv kubelet.service /etc/systemd/system/kubelet.service
  sudo mv kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Kubelet configured \e[0m"
}

# Configure the Kube-Proxy
setup_kubeproxy(){
  sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  sudo mv kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml
  sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Kube-Proxy configured \e[0m"
}

# Start the Worker Services
start_services(){
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Worker services started \e[0m"
}

echo ${NODE_ID}
init_setup
download_binaries
install_containerd
setup_containerd
configure_cni
setup_kubelet
setup_kubeproxy
start_services