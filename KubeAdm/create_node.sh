# Install initial packages
sudo apt update 
sudo apt-get install -y containerd apt-transport-https ca-certificates curl

# Ensure swap is off within the system
swapoff -a

sudo modprobe overlay 
sudo modprobe br_netfilter 

# make sure the system maintains the values once it reboots
cat <<EOF |sudo tee /etc/fstab
#
EOF

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system # apply systcl configurations without reboot

# install containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# change the value using sed
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# install kubernetes on the system
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update

sudo apt-get install -y kubeadm kubectl kubelet
sudo apt-mark hold kubelet kubeadm kubectl containerd

sudo systemctl enable kubelet
sudo systemctl enable containerd


# #=================bootstrapping control panel=====================##
# sudo kubeadm init

# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# #=============configure the cidr==============##
# wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
# kubectl apply -f calico.yml

# #============== getting the join token==========##
# kubeadm token create --print-join-command

##=================join a cluster=====================##

# #change the values of the ip and token
# sudo kubeadm join 172.31.100.220:6443 --token 7wtmft.6ou5zpsfx0msjfzb --discovery-token-ca-cert-hash sha256:9f02a1f83e91514d55c34ea7a86e51b1607843fc00a85c45106bb9b92bb39965

sudo kubeadm join 172.31.25.32:6443 --token xqesx1.ighl7weq72h9guvk --discovery-token-ca-cert-hash sha256:9d18d1c1142ffbe918466448e435324b03a87aa49f85cd9e9a7699b0eb1bc67a