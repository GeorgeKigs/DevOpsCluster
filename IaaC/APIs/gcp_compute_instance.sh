gcloud compute instances create instance-20241005-112606 \
--project=clgcporg8-092 \
--zone=us-central1-a --machine-type=e2-small --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
--maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=79815166977-compute@developer.gserviceaccount.com \
--scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
--tags=http-server,https-server --create-disk=auto-delete=yes,boot=yes,device-name=instance-20241005-112606,image=projects/debian-cloud/global/images/debian-12-bookworm-v20240910,mode=rw,size=10,type=pd-standard \
--no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ec-src=vm_add-gcloud --reservation-affinity=any