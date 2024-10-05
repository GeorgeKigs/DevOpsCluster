
sudo useradd -M -r -s /bin/false node_exporter

wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz

tar xvfz node_exporter-0.18.1.linux-amd64.tar.gz

sudo cp node_exporter-0.18.1.linux-amd64/node_exporter /usr/local/bin/

sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF


sudo cp node_exporter.service /etc/systemd/system/node_exporter.service

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

# text manipulation on the collector to enable us to add the nodes automatically
# ...

#   - job_name: 'LimeDrop Web Server'
#     static_configs:
#     - targets: ['10.0.1.102:9100']

# ...