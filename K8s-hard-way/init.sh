# Worker nodes
# This script is used to generate the certificates and keys for the Kubernetes cluster
# It is based on the tutorial from Kelsey Hightower: 
# https://github.com/kelseyhightower/kubernetes-the-hard-way


### TODO: Check how we can test the validity of the certificates

: '
Options to use as variables:
-m ==> k8s-hardway ==> Master node name
-l ==> k8s-hardway ===> Load balancer name
-w ==> k8s-hardway-nodes ==> Master node name
'

while getopts ":m:w:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODES_NAME="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done


checking_prerequisites(){
  # For this to work we need to install the following tools:
  # - cfssl ==> sudo apt-get install golang-cfssl
  # - cfssljson  ==> Installed with cfssl
  # - aws-cli ==> sudo apt-get install awscli

  ### AWS CLI configurations 
  echo "Checking if aws-cli is installed"
  if ! [ -x "$(command -v aws)" ]; then
    echo 'Error: aws-cli is not installed.' >&2
    echo "====Installing aws-cli===="

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    echo -e "\xE2\x9C\x94 aws-cli is installed"
  fi
  echo -e "\xE2\x9C\x94 aws-cli is installed"

  echo "==== Checking if aws-cli is configured ===="
  if ! [ -x "$(command -v aws configure)" ]; then
    echo -e '\u2718 Error: aws-cli is not configured.' >&2
    echo "Please run aws configure"
    exit 1
  fi
  echo -e "\xE2\x9C\x94 aws-cli is configured"


  echo "==== Getting the keys file ===="
  ##### CFSSL #####
  # Check if cfssl and aws-cli are installed
  if ! [ -x "$(command -v cfssl)" ]; then
    echo '\u2718 Error: cfssl is not installed.' >&2
    echo "====Installing cfssl===="
    sudo apt-get install golang-cfssl
  fi
  echo -e "\xE2\x9C\x94 cfssl is installed"
}

define_vars(){
  #### AWS NODE RESULTS ####
  # expected output ===> i-0122b09d7f47e06f9

  RAW_MASTER_JSON=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}" )
  RAW_WORKER_JSON=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${WORKER_NODES_NAME}" )

  KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers\
    --names ${LOADBALANCER_NAME}\
    --query "LoadBalancers[].DNSName"\
    --output text)

  MASTER_NODE=$(echo $RAW_MASTER_JSON | jq -r '.Reservations[].Instances[].InstanceId')
  echo -e "\xE2\x9C\x94 Master node is ${MASTER_NODE}"

  WORKER_NODES=$(echo $RAW_WORKER_JSON | jq -r '.Reservations[].Instances[].InstanceId')
  echo -e "\xE2\x9C\x94 Worker nodes are ${WORKER_NODES}"

  # expected output ===> k8s-hardway
  SINGLE_MASTER_INSTANCE=$(echo $MASTER_NODE| awk '{print $1}')
  echo -e "\xE2\x9C\x94 Single master instance is ${SINGLE_MASTER_INSTANCE}"

  KEY_FILE=$(echo $(echo $RAW_MASTER_JSON | jq -r '.Reservations[].Instances[].KeyName') | awk '{print $1}')
  echo -e "\xE2\x9C\x94 Keys file is ${KEY_FILE}"

  # ? find a better way to store the key file
  if [ ! -f "${KEY_FILE}.pem" ]; then
    echo "\u2718 Error: ${KEY_FILE}.pem file does not exist" >&2
    exit 1
  fi

  echo -e "\xE2\x9C\x94 ${KEY_FILE}.pem file exists"
  
}


# check if folder exists
change_dir(){
  if [ ! -d "certificates" ]; then
    mkdir -p certificates
  fi
  echo "Changing directory to certificates"
  cd certificates
}

define_certicate(){
  CN=$1
  O=$2
  FILE_NAME=$3
  cat > ${FILE_NAME}.json <<EOF
{
  "CN": "${CN}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "${O}",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  echo -e "\xE2\x9C\x94 ${FILE_NAME}.json is created"
}

# Genereate a CA certificate and private key
generate_ca_certs(){
  cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
  FILE_NAME="ca-csr"
  define_certicate "Kubernetes" "Kubernetes" ${FILE_NAME}
  
  cfssl gencert -initca ${FILE_NAME}.json | cfssljson -bare ca

  # Check on the certificates
  openssl x509 -in ca.pem -text -noout

}


# CA certificate for the admin controller
admin_controller(){
  FILE_NAME="admin-csr"
  define_certicate "admin" "system:masters" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare admin
}


# Generate the CA for the worker nodes
worker_nodes(){
  for instance in $WORKER_NODES; do

    FILE_NAME="${instance}-csr"
    define_certicate "system:node:${instance}" "system:nodes" ${FILE_NAME}

    EXTERNAL_IP=$(echo $RAW_WORKER_JSON | \
      jq --arg instance "$instance" -r '.Reservations[].Instances[] | select(.InstanceId==$instance) | .PublicIpAddress')

    INTERNAL_IP=$(echo $RAW_WORKER_JSON | \
      jq --arg instance "$instance" -r '.Reservations[].Instances[] | select(.InstanceId==$instance) | .PrivateIpAddress')

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
      -profile=kubernetes \
      ${FILE_NAME}.json | cfssljson -bare ${instance}
  done
}


# certificate for the control manager
control_manager(){

  FILE_NAME="kube-controller-manager-csr"
  define_certicate "system:kube-controller-manager" "system:kube-controller-manager" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare kube-controller-manager
}


# certificate for the kube-proxy
kube_proxy(){
  FILE_NAME="kube-proxy-csr"
  define_certicate "system:kube-proxy" "system:node-proxier" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare kube-proxy
}


# certificate for the scheduler
scheduler(){
  FILE_NAME="kube-scheduler-csr"
  define_certicate "system:kube-scheduler" "system:kube-scheduler" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare kube-scheduler
}


# certificate for the Kubernetes API server
api_server(){
  FILE_NAME="kubernetes-csr"
  define_certicate "kubernetes" "Kubernetes" ${FILE_NAME}

  ## Get the public address of the load balancer
  MASTER_PUBLIC_IP=$(echo $(echo $RAW_MASTER_JSON \
    | jq -r '.Reservations[].Instances[].PublicIpAddress')
    | sed 's/\t/,/g')

  echo -e "\xE2\x9C\x94 Master public ip is ${MASTER_PUBLIC_IP}"
  # seperate the text with , as the delimiter

  KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

  local INTERNAL_IP=$(echo $(echo $RAW_WORKER_JSON \
    | jq -r ".Reservations[].Instances[].PrivateIpAddress" ) \
    | sed 's/\t/,/g')

  echo -e "\xE2\x9C\x94 Master internal ip is ${INTERNAL_IP}"
  # Check on the ips used

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${INTERNAL_IP},${MASTER_PUBLIC_IP},127.0.0.1,${KUBERNETES_HOSTNAMES} \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare kubernetes
}


# certificate for the Kubernetes Service Account
service_account(){
  FILE_NAME="service-account-csr"
  define_certicate "service-accounts" "Kubernetes" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${FILE_NAME}.json | cfssljson -bare service-account
}


# Distribute the certificates and keys to the worker nodes

: '
Options to use as variables:
-m ==> eu-west-1-k8s-hardway-main ==> Master node name
-w ==> k8s-hardway-nodes ==> Worker nodes name
-l ==> k8s-hardway-nlb ===> Load balancer name
'

# -m m k8s-hardway -w k8s-hardway-nodes -l k8s-hardway

define_kubeconfigs(){
    local SERVER=$1
    local FILE_NAME=$2

    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=https://${SERVER}:6443 \
        --kubeconfig=${FILE_NAME}.kubeconfig

    kubectl config set-credentials system:${FILE_NAME} \
        --client-certificate=${FILE_NAME}.pem \
        --client-key=${FILE_NAME}-key.pem \
        --embed-certs=true \
        --kubeconfig=${FILE_NAME}.kubeconfig

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:${FILE_NAME} \
        --kubeconfig=${FILE_NAME}.kubeconfig

    kubectl config use-context default --kubeconfig=${FILE_NAME}.kubeconfig

}

# The configs will be created on the controller nodes
controller_configs(){

  for instance in ${WORKER_NODES}; do
    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
      --kubeconfig=${instance}.kubeconfig

    kubectl config set-credentials system:node:${instance} \
      --client-certificate=${instance}.pem \
      --client-key=${instance}-key.pem \
      --embed-certs=true \
      --kubeconfig=${instance}.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:node:${instance} \
      --kubeconfig=${instance}.kubeconfig

    kubectl config use-context default --kubeconfig=${instance}.kubeconfig
  done
}


# The kube-proxy Kubernetes Configuration File
kube_proxy_configs(){
  define_kubeconfigs ${KUBERNETES_PUBLIC_ADDRESS} kube-proxy
  define_kubeconfigs "127.0.0.1" kube-controller-manager
  define_kubeconfigs '127.0.0.1' kube-scheduler
  define_kubeconfigs '127.0.0.1' admin
}

# encryption config file
define_encryption(){
    local ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

    cat > encryption-config.yaml <<EOF
apiVersion: v1
kind: EncryptionConfig
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
}

# distribute the kubeconfig files to the worker nodes
distribute_worker_configs(){

  for instance in $WORKER_NODES; do
      DNS_NAME=$(echo $RAW_WORKER_JSON | \
          jq --arg instance "$instance" -r '.Reservations[].Instances[] | select(.InstanceId==$instance) | .PublicDnsName')

      scp -i ../${KEY_FILE}.pem ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}-key.pem ${instance}.pem ca.pem ubuntu@${DNS_NAME}:~/

      # success message
      echo -e "\xE2\x9C\x94 ${instance} kubeconfig file has been distributed successfully"
  done
}

# distribute the kubeconfig files and encryption to the controller manager nodes
distribute_controller_configs(){

  for instance in $MASTER_NODE; do
      DNS_NAME=$(echo $RAW_MASTER_JSON | \
          jq --arg instance "$instance" -r '.Reservations[].Instances[] | select(.InstanceId==$instance) | .PublicDnsName')

      scp -i ../${KEY_FILE}.pem ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
          service-account-key.pem service-account.pem admin.kubeconfig kube-controller-manager.kubeconfig \
          kube-scheduler.kubeconfig encryption-config.yaml ubuntu@${DNS_NAME}:~/
      
      # success message
      echo -e "\xE2\x9C\x94 ${instance} kubeconfig file has been distributed successfully"
  done
}

checking_prerequisites
define_vars
define_encryption
controller_configs
kube_proxy_configs
generate_ca_certs
admin_controller
worker_nodes
control_manager
kube_proxy
scheduler
api_server
service_account
distribute_workers
distribute_controllers
