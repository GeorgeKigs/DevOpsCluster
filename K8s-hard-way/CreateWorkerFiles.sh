POD_CIDR="10.0.1.0/24"

while getopts ":i:" opt; do
  case $opt in
    i) NODE_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

create_files(){
cat > 10-bridge.conf <<EOF 
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# success message to create 10-bridge.conf
echo -e "\e[32m \xE2\x9C\x94 10-bridge.conf file created successfully\e[0m"

cat > 99-loopback.conf <<EOF 
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF

# success message to create 99-loopback.conf
echo -e "\e[32m \xE2\x9C\x94 99-loopback.conf file created successfully\e[0m"

cat > config.toml << EOF
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

# success message to create config.toml
echo -e "\e[32m \xE2\x9C\x94 config.toml file created successfully\e[0m"

cat > containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

# success message to create containerd.service
echo -e "\e[32m \xE2\x9C\x94 containerd.service file created successfully\e[0m"

cat > kubelet-config.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.1.124"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

# success message to create kubelet-config.yaml
echo -e "\e[32m \xE2\x9C\x94 kubelet-config.yaml file created successfully\e[0m"

cat > kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create kubelet.service
echo -e "\e[32m \xE2\x9C\x94 kubelet.service file created successfully\e[0m"

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > kube-proxy-config.yaml<<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${POD_CIDR}"
EOF
}

define_variables(){
  
  # success message to get node ids
  echo -e "\e[32m \xE2\x9C\x94 Node IDs are: ${NODE_IDS}\e[0m"
  
  HOSTNAME=${NODE_ID}

  DNS_NAME=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${NODE_ID}" \
    --query "Reservations[*].Instances[*].PublicDnsName" \
    --output text)

  # success message to get dns name
  echo -e "\e[32m \xE2\x9C\x94 DNS Name is: ${DNS_NAME}\e[0m"

  KEY_FILE=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${NODE_ID}" \
    --query "Reservations[*].Instances[*].KeyName" \
    --output text)

  # success message to get key file
  echo -e "\e[32m \xE2\x9C\x94 Key File is: ${KEY_FILE}\e[0m"

  KEY="${home_dir}/${KEY_FILE}.pem"

}

push_cloud(){
  local KEY=$1
  local DNS_NAME=$2

  sudo scp -i ${KEY} \
    10-bridge.conf 99-loopback.conf config.toml\
    containerd.service kubelet-config.yaml kubelet.service BootstrapWorkers.sh\
    kube-proxy-config.yaml kube-proxy.service \
    ubuntu@${DNS_NAME}:~/
  
  # success message to push files to cloud
  echo -e "\e[32m \xE2\x9C\x94 Files pushed to cloud\e[0m"
}

NODE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${NODE_NAME}" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

home_dir=$(pwd)
echo -e "\e[32m \xE2\x9C\x94 ${home_dir} \e[0m"

for NODE_ID in ${NODE_IDS}; do

  define_variables

  echo -e "\e[32m \xE2\x9C\x94 Worker Node is ${NODE_ID} \e[0m "

  mkdir -p ${home_dir}/certificates/${NODE_ID}
  cp BootstrapWorkers.sh ${home_dir}/certificates/${NODE_ID}

  cd ${home_dir}/certificates/${NODE_ID}

  create_files

  push_cloud ${KEY} ${DNS_NAME}

  echo ${NODE_ID}
  sudo ssh -i ${KEY} ubuntu@${DNS_NAME} "bash BootstrapWorkers.sh -i ${NODE_ID}"

  cd ${home_dir}
done