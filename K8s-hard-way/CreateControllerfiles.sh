# get the args for the script
CIDR=""
while getopts ":i:" opt; do
  case $opt in
    i) NODE_NAME="$OPTARG";;
    # l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done


create_files(){
  echo -e "\e[32m \xE2\x9C\x94 Creating files\e[0m"

# The etc Kubernetes Configuration File
cat > etcd.service << EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_NAME}=https://${INTERNAL_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create etcd.service
echo -e "\e[32m \xE2\x9C\x94 etcd.service file created successfully\e[0m"


# The Kubernetes API Server Configuration File
cat > kube-apiserver.service <<EOF 
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://${INTERNAL_IP}:6443 \\
  --service-cluster-ip-range=10.0.1.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create kube-apiserver.service
echo -e "\e[32m \xE2\x9C\x94 kube-apiserver.service file created successfully\e[0m"


# change the cidr block configurations to enable pod communication
# The Kubernetes Controller Manager Configuration File
cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create kube-controller-manager.service
echo -e "\e[32m \xE2\x9C\x94 kube-controller-manager.service file created successfully\e[0m"

# The Kubernetes Scheduler Yaml File
cat  > kube-scheduler.yaml <<EOF
apiVersion: kubescheduler.config.k8s.io/v1beta1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

# success message to create kube-scheduler.yaml
echo -e "\e[32m \xE2\x9C\x94 kube-scheduler.yaml file created successfully\e[0m"

# kube-scheduler.service file
cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create kube-scheduler.service
echo -e "\e[32m \xE2\x9C\x94 kube-scheduler.service file created successfully\e[0m"

# The RBAC for Kube-apiserver to Kubelet
cat > rbac.yaml <<EOF 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

# success message to create rbac.yaml
echo -e "\e[32m \xE2\x9C\x94 rbac.yaml file created successfully\e[0m"

# define nginx health checks
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

# success message to create kubernetes.default.svc.cluster.local
echo -e "\e[32m \xE2\x9C\x94 kubernetes.default.svc.cluster.local file created successfully\e[0m"
}

define_variables(){
  
  # success message to get node ids
  echo -e "\e[32m \xE2\x9C\x94 Node IDs are: ${NODE_IDS}\e[0m"

  INTERNAL_IP=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${NODE_ID}" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)

  # success message to get internal ip
  echo -e "\e[32m \xE2\x9C\x94 Internal IP is: ${INTERNAL_IP}\e[0m"

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

  # KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers\
  #   --names ${LOADBALANCER_NAME}\
  #   --query "LoadBalancers[].AvailabilityZones[].LoadBalancerAddresses[].IpAddress[]"\
  #   --output text)

  # # success message to get kubernetes public address
  # echo -e "\e[32m \xE2\x9C\x94 Kubernetes Public Address is: ${KUBERNETES_PUBLIC_ADDRESS}\e[0m"

  # ETCD_NAME=$(sudo ssh -i "${KEY}" ubuntu@${DNS_NAME} "hostname -s")
  ETCD_NAME=${NODE_ID}

  # success message to get etcd name
  echo -e "\e[32m \xE2\x9C\x94 Etcd Name is: ${ETCD_NAME}\e[0m"

  REGION=$(aws configure get region --output text)
}

push_cloud(){
  local KEY=$1
  local DNS_NAME=$2

  sudo scp -i ${KEY} \
    etcd.service kube-apiserver.service kube-scheduler.yaml kube-controller-manager.service \
    kube-scheduler.service rbac.yaml kubernetes.default.svc.cluster.local \
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

  echo -e "\e[32m \xE2\x9C\x94 Master node is ${NODE_ID} \e[0m "

  mkdir -p ${home_dir}/certificates/${NODE_ID}
  cp BootstrapControllers.sh ${home_dir}/certificates/${NODE_ID}

  cd ${home_dir}/certificates/${NODE_ID}

  # create_files

  # push_cloud ${KEY} ${DNS_NAME}
  sudo ssh -i ${KEY} ubuntu@${DNS_NAME} "bash -s" < ${home_dir}/BootstrapControllers.sh

  cd ${home_dir}
done