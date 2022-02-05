#!/bin/bash

## Install dependencies
apt-get install -y jq awscli gnupg lsb-release ca-certificates software-properties-common nfs-common
groupadd developers
##Install Node Exporter (Prometheus)
mkdir -p /opt/node-exporter
url="$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | jq .assets[2].browser_download_url)"
curl -L "$(echo "$url" | cut -c 2-$((${#url}-1)))" -o node-exporter.tar.gz
tar xvf node-exporter.tar.gz
mv node_exporter-* node-exporter
mv node-exporter/* /opt/node-exporter
rm -r node-exporter*
adduser --system --shel /bin/false --no-create-home --disabled-login node-exporter

echo 'DNS=172.16.0.254' >> /etc/systemd/resolved.conf

##Install GPG keys & APT Repositories
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
apt-get update
apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

##Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io

##Install Kubernetes
apt-get install -y kubeadm kubelet kubectl
swapoff –a
sed -i 's/\/swap.img/#\/swap.img/g' /etc/fstab

#Generate SSL certificate, MUST BE REFRESHED EVERY 8 DAYS!!!!!
myIp=""
read -ra "output" <<< "$(hostname -I)"
for ip in "${output[@]}"
do
  if [[ "$ip" == *"172.16.0"* ]]; then
    myIp=$ip
    break;
  fi
done

curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/openssl.conf > ./openssl.conf
sed -i "s/\${POD_IP}/$myIp/g" ./openssl.conf
sed -i "s/\${SERVICE_NAME}/$(hostname)/g" ./openssl.conf
echo "$3"

openssl req -newkey rsa:4096 -nodes -keyout /opt/node-exporter/private.pem -days 8 -out ./public.csr -config ./openssl.conf
echo 'Enter AWS Access Key Id.'
read -r AWS_ACCESS_KEY_ID
echo 'Enter AWS Secret Access Key'
read -r AWS_SECRET_ACCESS_KEY

mkdir -p ~/.aws/

cat << EOF > ~/.aws/credentials
[default]
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_access_key_id = $AWS_ACCESS_KEY_ID
EOF

cat << EOF > ~/.aws/config
[default]
region = us-east-1
output = json

EOF


username=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificateUsername | jq .SecretString)
echo $username
password=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id certificatePassword | jq .SecretString)
username=$(echo "$username" | cut -c 2-$((${#username}-1)))
password=$(echo "$password" | cut -c 2-$((${#password}-1)))

rm -rf ~/.aws/config

certificateRequest=$(cat ./public.csr)
certificateRequest=$(printf "%q" "$certificateRequest")
certificateRequest=$(echo "$certificateRequest" | cut -c 3-$((${#certificateRequest}-1)))
certificateRequest="{\"certificateRequest\":\"$certificateRequest\",\"ip\":\"$myIp\"}"
curl --insecure https://zevrant-01.zevrant-services.com:9009/zevrant-certificate-service/certs --data "$certificateRequest" \
  --user "$username":"$password" -H "Content-Type: application/json" -X POST -o /opt/node-exporter/public.crt
rm openssl.conf public.csr
cat << EOF > /etc/systemd/system/node-exporter.service
[Unit]
Description=Node Exporter
Documentation=

Wants=network.target
After=network.target

[Service]
User=node-exporter

WorkingDirectory=/opt/node-exporter
ExecStart=/opt/node-exporter/node_exporter --web.config=/opt/node-exporter/config.yml

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/kubeconfig.service
[Unit]
Description=Kube Config

Before=network.target

[Service]
User=root
ExecStart=/usr/local/bin/kubeconfig.sh

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/lvm-configurer.service
[Unit]
Description=Kube Config

Before=network.target

[Service]
User=root
ExecStart=chown nbd /dev/nfs-vg/nfs-lv

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/local/bin/kubeconfig.sh
#!/bin/bash
sysctl net.ipv4.conf.all.forwarding=1
iptables -P FORWARD ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables --flush
iptables -tnat --flush
net.bridge.bridge-nf-call-iptables = 1
EOF

cat << EOF > /opt/node-exporter/config.yml
tls_server_config:
  cert_file: public.crt
  key_file: private.pem
EOF

echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
sysctl -p

chown -R node-exporter:developers /opt/node-exporter
chown root:root /usr/local/bin/kubeconfig.sh
chmod 0700 /usr/local/bin/kubeconfig.sh

#Start & Enable Services
systemctl daemon-reload
systemctl start docker
systemctl start kubelet

sleep 10

[ -z "$(systemctl status docker | grep active)" ] && echo "Docker has failed to start"
[ -z "$(systemctl status kubelet | grep active)" ] && echo "Kubelet has failed to start"

usermod -G docker zevrant

curl https://raw.githubusercontent.com/zevrant/zevrant-services-pipeline/master/bash/zevrant-services.crt \
      -o /usr/local/share/ca-certificates/zevrant-services.crt \
    && update-ca-certificates -v \
    && ls -l /etc/ssl/certs/zevrant-services.pem

systemctl enable node-exporter
systemctl enable kubeconfig
systemctl enable docker
sed -i 's~ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock~ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --exec-opt native.cgroupdriver=systemd~g' /lib/systemd/system/docker.service

echo "Installation Complete Press Enter to Reboot"
read -r
reboot
