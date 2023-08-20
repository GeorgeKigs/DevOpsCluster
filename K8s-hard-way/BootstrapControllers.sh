LATEST_K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)

install_etcd(){

    wget --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz"
  
    tar -xvf etcd-v3.4.15-linux-amd64.tar.gz
    sudo mv etcd-v3.4.15-linux-amd64/etcd* /usr/local/bin/

    sudo rm -rf /etc/etcd /var/lib/etcd

    sudo mkdir -p /etc/etcd /var/lib/etcd

    # success message if the command is successful

    sudo chmod 700 /var/lib/etcd
    sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
    sudo mv etcd.service /etc/systemd/system/etcd.service

    echo -e "\e[32m \xE2\x9C\x94 Success creation of etcd\e[0m"

}

install_controller(){
  sudo mkdir -p /etc/kubernetes/config
  wget --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/${LATEST_K8S_VERSION}/bin/linux/amd64/kubectl"

  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Success installation of the controller \e[0m"
}

install_api_server(){
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
  
  sudo mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Success creation of api server \e[0m"
}

install_controller_manager(){
  sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
  sudo mv kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Success creation of controller manager \e[0m"
}

install_scheduler(){
  sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
  sudo mv kube-scheduler.yaml /etc/kubernetes/config/kube-scheduler.yaml
  sudo mv kube-scheduler.service /etc/systemd/system/kube-scheduler.service

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Success creation of scheduler \e[0m"
}

initialise(){
  sudo systemctl daemon-reload
  sudo systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start etcd kube-apiserver kube-controller-manager kube-scheduler

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Successful initialisation of the main cluster \e[0m"
}

initialise_rbac(){
  kubectl apply -f rbac.yaml
}

# enable http health checks
health_check(){
  sudo apt-get install -y nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx
  sudo mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

  sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
  sudo systemctl restart nginx
  sudo systemctl enable nginx

  # success message if the command is successful
  echo -e "\e[32m \xE2\x9C\x94 Success creation of health checks \e[0m"
}

verify(){
  sudo systemctl status etcd
  sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem

  kubectl cluster-info --kubeconfig admin.kubeconfig
}

install_etcd
install_controller
install_api_server
install_controller_manager
install_scheduler
initialise
initialise_rbac
health_check
# verify
