# todo: try to use jq for the individual worker nodes

while getopts ":m:w:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODE_NAME="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done


# getting the load balancer dns name
LOADBALANCER_DNS_NAME=$(aws elbv2 describe-load-balancers\
  --names ${LOADBALANCER_NAME}\
  --query "LoadBalancers[].DNSName[]"\
  --output text)

echo -e "\e[32m \xE2\x9C\x94 Load Balancer DNS Name is: ${LOADBALANCER_DNS_NAME}\e[0m"

# getting the worker node details
RAW_JSON=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${WORKER_NODE_NAME}")

#### SUBNETS ####
# getting the subnet details to get the cidr block
MASTER_NODE_SUBNET_ID=$(echo $(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}" | \
  jq -r '.Reservations[].Instances[].SubnetId') | awk '{print $1}')

WORKER_NODE_SUBNET_ID=$(echo $RAW_JSON | jq -r '.Reservations[].Instances[].SubnetId')

SERVICE_CIDR=$(aws ec2 describe-subnets \
  --filters "Name=subnet-id,Values=${MASTER_NODE_SUBNET_ID}" | \
  jq -r '.Subnets[].CidrBlock')

POD_CIDR=$(aws ec2 describe-subnets \
  --filters "Name=subnet-id,Values=${WORKER_NODE_SUBNET_ID}" | \
  jq -r '.Subnets[].CidrBlock')

# success message to get the cidr block
echo -e "\e[32m \xE2\x9C\x94 Service CIDR is: ${SERVICE_CIDR}\e[0m"
echo -e "\e[32m \xE2\x9C\x94 Pod CIDR is: ${POD_CIDR}\e[0m"

# getting the worker node details
NODE_IDS=$(echo $RAW_JSON | jq -r '.Reservations[].Instances[].InstanceId')

KEY_FILE=$(echo $(echo $RAW_JSON | jq -r '.Reservations[].Instances[].KeyName') | awk '{print $1}')

# success message to get key file
echo -e "\e[32m \xE2\x9C\x94 Key File is: ${KEY_FILE}\e[0m"

KEY="${home_dir}/${KEY_FILE}.pem"
home_dir=$(pwd)

# success message to get home directory
echo -e "\e[32m \xE2\x9C\x94 ${home_dir} \e[0m"


create_networking_files(){

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

}

containerd_files(){
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
}


kubeconfig_files(){

HOSTNAME=$1
# todo: check on the clusterDNS Value. I think it should be the kubernetes service ip

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
  - "${LOADBALANCER_DNS_NAME}"
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

bootstrap_worker(){
  NODE_ID=$1
  
  echo -e "\e[32m \xE2\x9C\x94 Bostrapping the worker node: ${NODE_IDS}\e[0m"
  
  DNS_NAME=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${NODE_ID}" \
    --query "Reservations[*].Instances[*].PublicDnsName" \
    --output text)

  # success message to get dns name
  echo -e "\e[32m \xE2\x9C\x94 DNS Name is: ${DNS_NAME}\e[0m"
  
  # bootstrap files
  create_networking_files
  containerd_files
  kubeconfig_files ${NODE_ID}

  # push the files to the instance
  sudo scp -i ${KEY} \
    10-bridge.conf 99-loopback.conf config.toml\
    containerd.service kubelet-config.yaml kubelet.service ${home_dir}/BootstrapWorkers.sh\
    kube-proxy-config.yaml kube-proxy.service \
    ubuntu@${DNS_NAME}:~/
  
  # success message to push files to cloud
  echo -e "\e[32m \xE2\x9C\x94 Files pushed to cloud\e[0m"

  # run the bootstrap script
  sudo ssh -i ${KEY} ubuntu@${DNS_NAME} "bash BootstrapWorkers.sh -i ${NODE_ID}"

}

for NODE_ID in ${NODE_IDS}; do

  echo -e "\e[32m \xE2\x9C\x94 Worker Node is ${NODE_ID} \e[0m "

  mkdir -p ${home_dir}/certificates/${NODE_ID}
  cp BootstrapWorkers.sh ${home_dir}/certificates/${NODE_ID}

  cd ${home_dir}/certificates/${NODE_ID}

  bootstrap_worker ${NODE_ID}
  
  cd ${home_dir}
done