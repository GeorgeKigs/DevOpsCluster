#!/usr/bin/env bash

# Created by @rkipkoech
# Ensure access keys are already set

# get required options
helpFunction()
{
  echo ""
  echo -e "\t-a Aws user arn"
  echo -e "\t-c Eks cluster name"
  echo -e "\t-r Aws region"
  echo -e "\t-t Gitlab Token"
  echo -e "\t-p Project name"
  echo -e "\t-b ALB role arn"
  exit 1 # Exit script after printing help
}

while getopts ":t:" opt
do
   case "$opt" in
      # a ) userArn="$OPTARG" ;;
      # r ) awsRegion="$OPTARG" ;;      
      t ) gitlabToken="$OPTARG" ;;
      # h ) fluxSopsKmsArn="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done


# install setup tools
installSetupTools() {
    # Install Fluxcli
    curl -s https://fluxcd.io/install.sh | sudo bash

    # Install Kubectl
    curl -LO https://dl.k8s.io/release/v1.27.1/bin/linux/amd64/kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    
    # install build & network troubleshooting tools
    
    sudo apt install gcc openssl-devel telnet jq -y
    
    # # install redis-cli
    wget http://download.redis.io/redis-stable.tar.gz && tar xvzf redis-stable.tar.gz && cd redis-stable && make BUILD_TLS=yes
    sudo cp -r src/redis-cli /usr/local/bin
    
    #install mongosh
#     cat <<EOF > /tmp/mongo-repo
# [mongodb-org-6.0]
# name=MongoDB Repository
# baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/6.0/x86_64/
# gpgcheck=1
# enabled=1
# gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
# EOF

#     sudo bash -c 'cat /tmp/mongo-repo > /etc/yum.repos.d/mongodb-org-6.0.repo'
    sudo apt install -y mongodb-mongosh
}


installFlux() {
    : '
    Key points to note within this script
    The required fields are:
    -> 
    '
    export GITLAB_TOKEN=$gitlabToken
    flux bootstrap gitlab \
    --hostname=gitlab.safaricom.co.ke \
    --owner=gndungu \
    --repository=crossplane-poc \
    --kubeconfig=/home/ubuntu/.kube/config \
    --branch=main   \
    --reconcile=true \
    --path=clusters/$projectName  \
    --components-extra=image-reflector-controller,image-automation-controller \
    --personal=true \
    --token-auth=true
}

cloneFluxRepo() {
    rm -rf /tmp/fluxv2-repo
    git clone https://oauth2:$gitlabToken@gitlab.safaricom.co.ke/gndungu/crossplane-poc.git /tmp/fluxv2-repo
}
 
initializeFluxInfra() {
    cd /tmp/fluxv2-repo 
    mkdir ./infrastructure/$projectName
    cat <<EOF > ./infrastructure/$projectName/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - metrics-server.yaml
  - developer-role.yaml
EOF

    flux create kustomization infra \
    --namespace=flux-system \
    --source=GitRepository/flux-system \
    --path="./infrastructure/$projectName" \
    --decryption-provider=sops \
    --interval=5m \
    --prune=true --export > ./clusters/$projectName/infra.yaml
}
 
installMetricsServer() {
    cd /tmp/fluxv2-repo 
    curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml > ./infrastructure/$projectName/metrics-server.yaml
}

AddDevAccessClusterRole() {
    cd /tmp/fluxv2-repo 
    cat <<EOF > ./infrastructure/$projectName/developer-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dev-full-access
rules:
- apiGroups:
  - ""
  - extensions
  - apps
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - batch
  resources:
  - jobs
  - cronjobs
  verbs:
  - '*'
EOF
}

install_crossplane(){
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
  helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --set "args='{ --debug,--enable-management-policies, --enable-environment-configs, --enable-composition-functions}'" \
  --set "xfn.enabled=true" \
  --set "xfn.args='{--debug}'"

  # install the aws provider
  cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v0.37.0
EOF

  # add the aws provider to the crossplane install
  kubectl create secret generic aws-secret -n crossplane-system --from-file=creds=./aws-credentials.txt
 


  alias kd='kubectl -n crossplane-system describe'
  alias ke='kubectl -n crossplane-system edit'
  alias kg='kubectl -n crossplane-system get'
  alias kdd='kubectl -n crossplane-system delete'
}

pushUpdatesToGit() {
  cd /tmp/fluxv2-repo 
  git add --all
  git commit -m "setup infra for $projectName"
  git push
}

installSetupTools
installFlux
cloneFluxRepo
initializeFluxInfra
installMetricsServer
AddDevAccessClusterRole
install_crossplane
pushUpdatesToGit
