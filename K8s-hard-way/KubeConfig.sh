: '
Options to use as variables:
-m ==> eu-west-1-k8s-hardway-main ==> Master node name
-w ==> k8s-hardway-nodes ==> Worker nodes name
-l ==> k8s-hardway-nlb ===> Load balancer name
'

# -m m k8s-hardway -w k8s-hardway-nodes -l k8s-hardway

while getopts ":m:w:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODES_NAME="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

# cd into certificates directory
checking_prerequisites(){
    # the folder certificates should be created in the same directory as this script
    if [ ! -d "certificates" ]; then
        echo "\u2718 Error: Please run Certificates.sh first" >&2
        exit 1
    else
        cd certificates
    fi
}

define_vars(){
    KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers\
        --names ${LOADBALANCER_NAME}\
        --query "LoadBalancers[].DNSName"\
        --output text)

    echo -e "\xE2\x9C\x94 Kubernetes Public Address is: ${KUBERNETES_PUBLIC_ADDRESS}"

    MASTER_NODE=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text)

    echo -e "\xE2\x9C\x94 Master node is ${MASTER_NODE}"

    EXTERNAL_MASTER_IP=$(aws ec2 describe-instances \
            --filters "Name=instance-id,Values=${MASTER_NODE}" \
            --query "Reservations[*].Instances[*].PublicIpAddress" \
            --output text)

    echo -e "\xE2\x9C\x94 Master node IP is ${EXTERNAL_MASTER_IP}"

    WORKER_NODES=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${WORKER_NODES_NAME}" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text)
    echo -e "\xE2\x9C\x94 Worker nodes are ${WORKER_NODES}"
    
    SINGLE_MASTER_INSTANCE=$(echo $MASTER_NODE| awk '{print $1}')

    KEY_FILE=$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=${SINGLE_MASTER_INSTANCE}" \
    --query "Reservations[*].Instances[*].KeyName" \
    --output text)

    if [ ! -f "../${KEY_FILE}.pem" ]; then
        echo -e "\u2718 Error: ${KEY_FILE}.pem file does not exist" >&2
        exit 1
    fi

    echo -e "\xE2\x9C\x94 ${KEY_FILE}.pem file exists"
  
}

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
}

# The kube-controller-manager Kubernetes Configuration File
controller_manager_configs(){
    define_kubeconfigs "127.0.0.1" kube-controller-manager
}

# The kube-scheduler Kubernetes Configuration File
scheduler_configs(){
    define_kubeconfigs '127.0.0.1' kube-scheduler
}

# The admin Kubernetes Configuration File
admin_configs(){
    define_kubeconfigs '127.0.0.1' admin
}

# encryption config file
define_encryption(){
    local ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

    cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
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
        DNS_NAME=$(aws ec2 describe-instances \
        --filters "Name=instance-id,Values=${instance}" \
        --query "Reservations[*].Instances[*].PublicDnsName" \
        --output text)

        scp -i ../${KEY_FILE}.pem ${instance}.kubeconfig kube-proxy.kubeconfig ubuntu@${DNS_NAME}:~/

        # success message
        echo -e "\xE2\x9C\x94 ${instance} kubeconfig file has been distributed successfully"
    done
}

# distribute the kubeconfig files and encryption to the controller manager nodes
distribute_controller_configs(){

    for instance in $MASTER_NODE; do
        DNS_NAME=$(aws ec2 describe-instances \
        --filters "Name=instance-id,Values=${instance}" \
        --query "Reservations[*].Instances[*].PublicDnsName" \
        --output text)

        scp -i ../${KEY_FILE}.pem admin.kubeconfig kube-controller-manager.kubeconfig \
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
controller_manager_configs
scheduler_configs
admin_configs
distribute_worker_configs
distribute_controller_configs