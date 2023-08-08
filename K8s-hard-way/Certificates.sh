# Worker nodes
# This script is used to generate the certificates and keys for the Kubernetes cluster
# It is based on the tutorial from Kelsey Hightower: 
# https://github.com/kelseyhightower/kubernetes-the-hard-way


while getopts ":m:w:k:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODES_NAME="$OPTARG";;
    k) KEY_FILE="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

checking_prerequisites(){
  # For this to work we need to install the following tools:
  # - cfssl ==> sudo apt-get install golang-cfssl
  # - cfssljson  ==> Installed with cfssl
  # - aws-cli ==> sudo apt-get install awscli

  echo "Checking if aws-cli is installed"
  if ! [ -x "$(command -v aws)" ]; then
    echo 'Error: aws-cli is not installed.' >&2
    echo "====Installing aws-cli===="

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

  else
    echo -e "\xE2\x9C\x94 aws-cli is installed"
    echo "Checking if aws-cli is configured"

    if ! [ -x "$(command -v aws configure)" ]; then
      echo -e '\u2718 Error: aws-cli is not configured.' >&2
      echo "Please run aws configure"
      exit 1
    fi

    echo -e "\xE2\x9C\x94 aws-cli is configured"
    echo "====Getting the key file===="

    # expected output ===> i-0122b09d7f47e06f9
    MASTER_NODE=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}" \
      --query "Reservations[*].Instances[*].InstanceId" \
      --output text)

    WORKER_NODES=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=${WORKER_NODES_NAME}" \
      --query "Reservations[*].Instances[*].InstanceId" \
      --output text)

    # expected output ===> k8s-hardway
    KEY_FILE=$(aws ec2 describe-instances \
      --filters "Name=instance-id,Values=${MASTER_NODE}" \
      --query "Reservations[*].Instances[*].KeyName" \
      --output text)
  fi

  # Check if cfssl and aws-cli are installed
  if ! [ -x "$(command -v cfssl)" ]; then
    echo '\u2718 Error: cfssl is not installed.' >&2
    echo "====Installing cfssl===="
    sudo apt-get install golang-cfssl
  else
    echo -e "\xE2\x9C\x94 cfssl is installed"
  fi
}
# check if folder exists

change_dir(){
  if [ ! -d "certificates" ]; then
    mkdir certificates
  fi
}

define_certicate(){
  CN=$1
  O=$2
  FILE_NAME=$3
  cat > certificates/${FILE_NAME}.json <<EOF
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
}

# Genereate a CA certificate and private key
generate_ca_certs(){
  cat > certificates/ca-config.json <<EOF
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
  
  cfssl gencert -initca certificates\ca-csr.json | cfssljson -bare ca
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
    certificate/${FILE_NAME}.json | cfssljson -bare admin
}

# Generate the CA for the worker nodes
worker_nodes(){
  for instance in worker-0 worker-1 worker-2; do

    FILE_NAME="${instance}-csr"
    define_certicate "system:node:${instance}" "system:nodes" ${FILE_NAME}

    EXTERNAL_IP=$(aws ec2 describe-instances \
      --filters "Name=instance-id,Values=${instance}" \
      --query "Reservations[*].Instances[*].PublicIpAddress" \
      --output text)

    INTERNAL_IP=$(aws ec2 describe-instances \
        --filters "Name=instance-id,Values=${instance}" \
        --query "Reservations[*].Instances[*].PrivateIpAddress" \
        --output text)

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
      -profile=kubernetes \
      certificate/${FILE_NAME}.json | cfssljson -bare ${instance}
  done
}

# certificate for the control manager
control_manger(){

  FILE_NAME="kube-controller-manager-csr"
  define_certicate "system:kube-controller-manager" "system:kube-controller-manager" ${FILE_NAME}

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    certificate/${FILE_NAME}.json | cfssljson -bare kube-controller-manager
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
    certificate/${FILE_NAME}.json | cfssljson -bare kube-proxy
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
    certificate/${FILE_NAME}.json | cfssljson -bare kube-scheduler
}

# certificate for the Kubernetes API server
: '
For this to work we will need a load balancer in front of the Kubernetes API servers
The load balancer will have a static IP address assigned to it
'
api_server(){
  FILE_NAME="kubernetes-csr"
  define_certicate "kubernetes" "Kubernetes" ${FILE_NAME}

  ## Get the public address of the load balancer
  KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers\
  --names ${LOADBALANCER_NAME}\
  --query "LoadBalancers[].AvailabilityZones[].LoadBalancerAddresses[].IpAddress[]"\
  --output text)

  KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
    -profile=kubernetes \
    certificate/${FILE_NAME}.json | cfssljson -bare kubernetes
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
    certificate/${FILE_NAME}.json | cfssljson -bare service-account
}

# Distribute the certificates and keys to the worker nodes
distribute_workers{
  for worker_instance in $WORKER_NODES; do

    # result should  be like this ec2-34-254-19-53.eu-west-1.compute.amazonaws.com
    DNS_NAME=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${worker_instance}" \
    --query "Reservations[*].Instances[*].PublicDnsName" \
    --output text)

    scp -i ${KEY_FILE}.pem  ${instance}-key.pem ${instance}.pem ubuntu@${DNS_NAME}:~/
  done
}

# Distribute the certificates and keys to the controller nodes
distribute_controllers(){
  for master_instance in $MASTER_NODE; do

    DNS_NAME=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${master_instance}" \
    --query "Reservations[*].Instances[*].PublicDnsName" \
    --output text)

    scp -i ${KEY_FILE} ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem ubuntu@${DNS_NAME}:~/
  done
}


checking_prerequisites
change_dir
generate_ca_certs
admin_controller
worker_nodes
control_manger
kube_proxy
scheduler
api_server
service_account
distribute_workers
distribute_controllers