# get the args for the script
: '
Options to use as variables:
-i ==> eu-west-1-k8s-hardway-main ==> Master node name
-l ==> k8s-hardway-nlb ===> Load balancer name
'

# // todo: convert the script to use jq instead of calling APIs directly
# // todo: get a cidr blocks that will be used for the cluster pods
# // todo: use a seperate cidr block for the cluster services
# // todo: set the master nodes within the same subnet as the services cidr block


# todo: check on how we can make initial cluster dynamic. Test it using jq
# // todo: change the cidr block configurations to enable pod communication
# CLUSTER_CIDR="10.0.0.128/16"
# SERVICE_CIDR="10.0.0.0/25"
home_dir=$(pwd)
echo -e "\e[32m \xE2\x9C\x94 ${home_dir} \e[0m"


while getopts ":m:w:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODE_NAME="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

#### LOAD BALANCER ####
# get the load balancer dns name    
LOADBALANCER_DNS_NAME=$(aws elbv2 describe-load-balancers\
  --names ${LOADBALANCER_NAME}\
  --query "LoadBalancers[].DNSName[]"\
  --output text)

echo -e "\e[32m \xE2\x9C\x94 Load Balancer DNS Name is: ${LOADBALANCER_DNS_NAME}\e[0m"

# getting the master node details
RAW_JSON=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}")

#### SUBNETS ####
# getting the subnet details to get the cidr block
MASTER_NODE_SUBNET_ID=$(echo $RAW_JSON | jq -r '.Reservations[].Instances[].SubnetId')

WORKER_NODE_SUBNET_ID=$(echo $(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=k8s-hardway-nodes" | \
  jq -r '.Reservations[].Instances[].SubnetId') | awk '{print $1}')

SERVICE_CIDR=$(aws ec2 describe-subnets \
  --filters "Name=subnet-id,Values=${MASTER_NODE_SUBNET_ID}" | \
  jq -r '.Subnets[].CidrBlock')

CLUSTER_CIDR=$(aws ec2 describe-subnets \
  --filters "Name=subnet-id,Values=${WORKER_NODE_SUBNET_ID}" | \
  jq -r '.Subnets[].CidrBlock')

#### NODES ####
# getting the configurations for the services
NODE_IDS=$(echo  $RAW_JSON | jq -r '.Reservations[].Instances[].InstanceId')

echo -e "\e[32m \xE2\x9C\x94 Node IDs are: ${NODE_IDS}\e[0m"
                                                                                      
# get the key file for a single node
KEY_FILE=$(echo $(echo $RAW_JSON | \
    jq -r '.Reservations[].Instances[].KeyName') | awk '{print $1}')

KEY="${home_dir}/${KEY_FILE}.pem"

echo -e "\e[32m \xE2\x9C\x94 Key File is: ${KEY_FILE}\e[0m"

# internal IPs should replace the tabs with 
MASTER_INTERNAL_IPS=$(echo $(echo $RAW_JSON | jq -r '.Reservations[].Instances[] | "\(.PrivateIpAddress)"') | sed 's/ /,/g')

echo -e "\e[32m \xE2\x9C\x94 Master Internal IPs are: ${MASTER_INTERNAL_IPS}\e[0m"

# todo: confirm if this is public or private ips
# ETCD server configurations
ETCD_VARS=$(echo $(echo $RAW_JSON | \
  jq -r '.Reservations[].Instances[] | "\(.InstanceId)=https://\(.PrivateIpAddress):2380"') \
  | sed 's/ /,/g')

echo -e "\e[32m \xE2\x9C\x94 ETCD Vars are: ${ETCD_VARS}\e[0m"

ETCD_SERVERS=$(echo $(echo $RAW_JSON | \
  jq -r '.Reservations[].Instances[] | "https://\(.PublicIpAddress):2379 https://\(.PrivateIpAddress):2379"') |\
  sed 's/ /,/g')

echo -e "\e[32m \xE2\x9C\x94 ETCD Servers are: ${ETCD_SERVERS}\e[0m"


etcd_configfiles(){
# Configurations for the etcd server
ETCD_NAME=$1
INTERNAL_IP=$2
echo -e "\e[32m \xE2\x9C\x94 Creating etcd files for ${ETCD_NAME}\e[0m"

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
  --initial-cluster ${ETCD_VARS} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create etcd.service
echo -e "\e[32m \xE2\x9C\x94 etcd.service file created successfully\e[0m"
}


kube_apiserver_config(){
# The Kubernetes API Server Configuration File
# // todo change the etcd server to use the loadbalancer dns name. 
# // todo: count the number of master nodes using (| tr ',' '\n' | wc -l)

INTERNAL_IP=$1
SERVER_COUNT=$(echo ${MASTER_INTERNAL_IPS} | tr ',' '\n' | wc -l)

cat > kube-apiserver.service <<EOF 
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=${SERVER_COUNT} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=${SERVER_COUNT} \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${ETCD_SERVERS} \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://${INTERNAL_IP}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\ 
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
}

kubecontroller_config(){
# The Kubernetes Controller Manager Configuration File

cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# success message to create kube-controller-manager.service
echo -e "\e[32m \xE2\x9C\x94 kube-controller-manager.service file created successfully\e[0m"
}


kubescheduler_config(){
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
}


nginx_healthcheck(){
  # The Nginx Proxy Configuration File
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

push_cloud(){
  # local KEY=$1
  local DNS_NAME=$1

  scp -i ${KEY} \
    etcd.service kube-apiserver.service kube-scheduler.yaml kube-controller-manager.service \
    kube-scheduler.service rbac.yaml kubernetes.default.svc.cluster.local \
    ubuntu@${DNS_NAME}:~/
  
  # success message to push files to cloud
  echo -e "\e[32m \xE2\x9C\x94 Files pushed to cloud\e[0m"

  ssh -i ${KEY} ubuntu@${DNS_NAME} "bash -s" < ${home_dir}/BootstrapControllers.sh
  # success message to bootstrap controllers
  echo -e "\e[32m \xE2\x9C\x94 Controllers bootstrapped successfully\e[0m"
}

# todo: create a function for global variables
# // todo: convert this to be used for multiple nodes
define_variables(){
  
  NODE_ID=$1
  # echo -e "\e[32m \xE2\x9C\x94 Node IDs are: ${NODE_IDS}\e[0m"

  INTERNAL_IP=$(echo $RAW_JSON |\
   jq --arg NODE_ID ${NODE_ID} \
   '.Reservations[].Instances[] | select(.InstanceId==$NODE_ID) | "\(.PrivateIpAddress)"')


  # success message to get internal ip
  echo -e "\e[32m \xE2\x9C\x94 Internal IP is: ${INTERNAL_IP}\e[0m"

  DNS_NAME=$(echo $RAW_JSON |\
   jq --arg NODE_ID ${NODE_ID} \
   '.Reservations[].Instances[] | select(.InstanceId==$NODE_ID) | "\(.PublicDnsName)"')

  echo -e "\e[32m \xE2\x9C\x94 DNS Name is: ${DNS_NAME}\e[0m"

  # ETCD_NAME=$(sudo ssh -i "${KEY}" ubuntu@${DNS_NAME} "hostname -s")
  
  # etcd_configfiles ${NODE_ID} ${INTERNAL_IP} 
  # kube_apiserver_config ${INTERNAL_IP} 
  # kubecontroller_config
  # kubescheduler_config
  # nginx_healthcheck

  # push_cloud ${DNS_NAME}
  
}


# todo: create a function to get the cidr blocks for the subnets that host the nodes
# todo: modify the ips 
for NODE_ID in ${NODE_IDS}; do

  echo -e "\e[32m \xE2\x9C\x94 Master node is ${NODE_ID} \e[0m "

  mkdir -p ${home_dir}/certificates/${NODE_ID}

  cd ${home_dir}/certificates/${NODE_ID}

  define_variables ${NODE_ID}

  cd ${home_dir}
done