#!/usr/bin/env bash

# Created by @rkipkoech
# Ensure access keys are already set

# get required options
helpFunction()
{
   echo ""
   echo "Usage: $0 -a userArn -c clusterName -r awsRegion -t gitlabToken -p projectName -b albRolearn -d accountId -f istioTag -g istioRevision -h fluxSopsKmsArn" 
   echo -e "\t-a Aws user arn"
   echo -e "\t-c Eks cluster name"
   echo -e "\t-r Aws region"
   echo -e "\t-t Gitlab Token"
   echo -e "\t-p Project name"
   echo -e "\t-b ALB role arn"
   exit 1 # Exit script after printing help
}

while getopts "a:c:r:t:p:b:d:f:g:h:" opt
do
   case "$opt" in
      a ) userArn="$OPTARG" ;;
      c ) clusterName="$OPTARG" ;;
      r ) awsRegion="$OPTARG" ;;      
      t ) gitlabToken="$OPTARG" ;;
      p ) projectName="$OPTARG" ;;
      b ) albRolearn="$OPTARG" ;;
      d ) accountId="$OPTARG" ;;
      f ) istioTag="$OPTARG" ;;
      g ) istioRevision="$OPTARG" ;;
      h ) fluxSopsKmsArn="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$userArn" ] || [ -z "$clusterName" ] || [ -z "$awsRegion" ] || [ -z "$gitlabToken" ] || [ -z "$projectName" ] || [ -z "$albRolearn" ]  || [ -z "$accountId" ]  || [ -z "$istioTag" ] || [ -z "$istioRevision" ] || [ -z "$accountId" ]  || [ -z "$istioTag" ] || [ -z "$fluxSopsKmsArn" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# install setup tools
installSetupTools() {
    # Install Fluxcli
    curl -s https://fluxcd.io/install.sh | sudo bash

    # Install Kubectl
    curl -LO https://dl.k8s.io/release/v1.27.1/bin/linux/amd64/kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    #install eksctl
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin

    # install awscli
    pip3 uninstall awscli
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    exec bash
    
    # install build & network troubleshooting tools
    sudo yum install gcc openssl-devel telnet jq -y
    
    # install redis-cli
    wget http://download.redis.io/redis-stable.tar.gz && tar xvzf redis-stable.tar.gz && cd redis-stable && make BUILD_TLS=yes
    sudo cp -r src/redis-cli /usr/local/bin
    
    #install mongosh
    cat <<EOF > /tmp/mongo-repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

    sudo bash -c 'cat /tmp/mongo-repo > /etc/yum.repos.d/mongodb-org-6.0.repo'
    sudo yum install -y mongodb-mongosh
}


updateKubeConfig() {
    aws eks --region $awsRegion update-kubeconfig --name $clusterName
}


installFlux() {
    export GITLAB_TOKEN=$gitlabToken
    flux bootstrap gitlab \
    --hostname=gitlab.safaricom.co.ke \
    --owner=devsecops/fluxv2 \
    --repository=fluxv2-aws \
    --branch=master   \
    --path=clusters/$projectName \
    --components-extra=image-reflector-controller,image-automation-controller \
    --token-auth
}

cloneFluxRepo() {
    rm -rf /tmp/fluxv2-repo
    git clone https://oauth2:$gitlabToken@gitlab.safaricom.co.ke/devsecops/fluxv2/fluxv2-aws.git /tmp/fluxv2-repo
}

updateFluxPatch() {
  cd /tmp/fluxv2-repo 
  # to update to first check existince of patch before adding
      cat <<EOF >> ./clusters/$projectName/flux-system/kustomization.yaml
patches:
- patch: |
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: kustomize-controller
      annotations:
        eks.amazonaws.com/role-arn: ${fluxSopsKmsArn}
  target:
    kind: ServiceAccount
    name: kustomize-controller
EOF
}
 
initializeFluxInfra() {
    cd /tmp/fluxv2-repo 
    mkdir ./infrastructure/$projectName
    cat <<EOF > ./infrastructure/$projectName/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - metrics-server.yaml
  - alb-controller.yaml
  - istio-base.yaml
  - istiod.yaml
  - istio-ingress.yaml
  - developer-role.yaml
EOF

  flux create kustomization infra \
  --namespace=flux-system \
  --source=GitRepository/flux-system \
  --path="./infrastructure/$projectName" \
  --decryption-provider=sops \
  --interval=5m \
  --prune=true \
  --export > ./clusters/$projectName/infra.yaml
}
 
installMetricsServer() {
    cd /tmp/fluxv2-repo 
    curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml > ./infrastructure/$projectName/metrics-server.yaml
}


AddDevAccessClusterRole() {
    cd /tmp/fluxv2-repo 
    cat <<EOF >> ./infrastructure/$projectName/developer-role.yaml
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

installAlbController() {
    cd /tmp/fluxv2-repo 
    flux create source helm eks \
    --url=https://aws.github.io/eks-charts \
    --interval=30m \
    --namespace=kube-system \
    --export  > ./infrastructure/$projectName/alb-controller.yaml
    
    cat <<EOF >> ./infrastructure/$projectName/alb-controller.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
spec:
  chart:
    spec:
      chart: aws-load-balancer-controller
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: eks
      version: 1.4.7
  values: 
    clusterName: ${clusterName}
    serviceAccount:
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: ${albRolearn}
  interval: 30m0s
EOF

}

installIstioPrerequisites() {
    #pull and push images to ecr
    docker login -u AWS -p $(aws ecr get-login-password --region $awsRegion) $accountId.dkr.ecr.$awsRegion.amazonaws.com

    docker pull istio/pilot:$istioTag
    docker pull istio/proxyv2:$istioTag
    
    docker tag istio/pilot:$istioTag $accountId.dkr.ecr.eu-west-1.amazonaws.com/istio/pilot:$istioTag
    docker tag istio/proxyv2:$istioTag $accountId.dkr.ecr.eu-west-1.amazonaws.com/istio/proxyv2:$istioTag
    
    docker push $accountId.dkr.ecr.eu-west-1.amazonaws.com/istio/pilot:$istioTag
    docker push $accountId.dkr.ecr.eu-west-1.amazonaws.com/istio/proxyv2:$istioTag
}

installIstio() {
    cd /tmp/fluxv2-repo 
    # create namespace
    cat <<EOF > ./infrastructure/$projectName/istio-base.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
EOF
    # create helm source
    flux create source helm istio \
    --url=https://istio-release.storage.googleapis.com/charts \
    --interval=10m \
    --namespace=istio-system \
    --export  >> ./infrastructure/$projectName/istio-base.yaml
    
    # create crds
    flux create hr istio-base \
    --interval=10m \
    --source=HelmRepository/istio \
    --chart=base \
    --chart-version=$istioTag \
    --namespace=istio-system \
    --depends-on="kube-system/aws-load-balancer-controller" \
    --export  >> ./infrastructure/$projectName/istio-base.yaml
    
    # istall istiod
    cat <<EOF > ./infrastructure/$projectName/istiod.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istiod
  namespace: istio-system
spec:
  chart:
    spec:
      chart: istiod
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: istio
      version: ${istioTag}
  dependsOn:
  - name: istio-base
    namespace: istio-system      
  values:  
    meshConfig:
      accessLogFile: '/dev/stdout'  
    global:
      hub: ${accountId}.dkr.ecr.eu-west-1.amazonaws.com/istio
    revision: ${istioRevision}
  interval: 10m0s
EOF

    # install ingressgateway
    cat <<EOF > ./infrastructure/$projectName/istio-ingress.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/rev: prod
  name: istio-ingress
---  
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istio-ingressgateway
  namespace: istio-ingress
spec:
  chart:
    spec:
      chart: gateway
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: istio-system
      version: ${istioTag}
  dependsOn:
  - name: istiod
    namespace: istio-system      
  values:  
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-name: ${awsRegion}-eks-test
        # service.beta.kubernetes.io/aws-load-balancer-internal: "true"
        # service.beta.kubernetes.io/load-balancer-source-ranges: "0.0.0.0/0"
        service.beta.kubernetes.io/aws-load-balancer-type: external
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
        service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: 'true'
        # service.beta.kubernetes.io/aws-load-balancer-ssl-cert:arn:aws:acm:eu-west-1:007182356151:certificate/8e0f1add-1f9f-430b-a99e-d9df47b8169a
        # service.beta.kubernetes.io/aws-load-balancer-ssl-ports: '443'
        service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: 'Owner=gndungu,ManagedBy=DevSecOps,OrgBackupPolicy=None,Project=eks-test,createdBy=Noah Makau,BusinessOwner=Digital Engineering'
    revision: ${istioRevision}
  interval: 10m0s
EOF

}

pushUpdatesToGit() {
  cd /tmp/fluxv2-repo 
  git add --all
  git commit -m "setup infra for $projectName"
  git push
}
setIstioRevision(){
  sleep 120
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istioTag sh -
  ./istio-${istioTag}/bin/istioctl x revision tag set prod --revision $istioRevision 
  kubectl delete pod --all -n istio-ingress 
}

# installSetupTools
# updateKubeConfig
# installFlux
# cloneFluxRepo
# updateFluxPatch
# initializeFluxInfra
# installMetricsServer
# AddDevAccessClusterRole
# installAlbController
# installIstioPrerequisites
# installIstio
# pushUpdatesToGit
# setIstioRevision
