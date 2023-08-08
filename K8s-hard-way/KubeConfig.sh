
while getopts ":m:w:k:l:" opt; do
  case $opt in
    m) MASTER_NODE_NAME="$OPTARG";;
    w) WORKER_NODES_NAME="$OPTARG";;
    k) KEY_FILE="$OPTARG";;
    l) LOADBALANCER_NAME="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2;;
  esac
done

# cd into certificates directory
define_vars(){
    KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers\
        --names ${LOADBALANCER_NAME}\
        --query "LoadBalancers[].AvailabilityZones[].LoadBalancerAddresses[].IpAddress[]"\
        --output text)

    MASTER_NODE=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${MASTER_NODE_NAME}" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text)

    WORKER_NODES=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${WORKER_NODES_NAME}" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text)
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
    for instance in WORKER_NODES; do
        DNS_NAME=$(aws ec2 describe-instances \
        --filters "Name=instance-id,Values=${worker_instance}" \
        --query "Reservations[*].Instances[*].PublicDnsName" \
        --output text)

    scp -i ${KEY_FILE} ${instance}.kubeconfig kube-proxy.kubeconfig ubuntu@${DNS_NAME}:~/
    done
}

# distribute the kubeconfig files and encryption to the controller manager nodes
distribute_controller_configs(){
    for instance in MASTER_NODE; do
        DNS_NAME=$(aws ec2 describe-instances \
        --filters "Name=instance-id,Values=${master_instance}" \
        --query "Reservations[*].Instances[*].PublicDnsName" \
        --output text)

    scp -i ${KEY_FILE} admin.kubeconfig kube-controller-manager.kubeconfig \
        kube-scheduler.kubeconfig encryption-config.yaml ubuntu@${DNS_NAME}:~/
    done
}

define_vars
define_encryption
controller_configs
kube_proxy_configs
controller_manager_configs
scheduler_configs
admin_configs
distribute_worker_configs
distribute_controller_configs