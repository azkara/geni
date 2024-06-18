#!/bin/bash

echo "[+] Checking for root permissions"
if [ "$EUID" -ne 0 ];then
    echo "Please run this script as root"
    exit 1
fi

echo "[+] Seeting needrestart to automatic to prevent restart pop ups"
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

echo "[+] Checking for updates"
apt-get update


echo "[+] Installing depenbdancies and MongoDB"
apt install dirmngr gnupg apt-transport-https ca-certificates software-properties-common sudo -y
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg --batch --yes -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bullseye/mongodb-org/7.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update
wget http://ftp.br.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.1w-0+deb11u1_amd64.deb
dpkg -i ./libssl1.1_1.1.1w-0+deb11u1_amd64.deb
apt-get update

echo "[+] Installing MongoDB"
apt-get install -y mongodb-org

echo "[+] Reloading MongoDB Service"
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

echo "[+] Installing Node.js"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install nodejs -y

echo "[+] Installing GenieACS"
sudo npm install -g genieacs@1.2.9

echo "[+] Configure Usergroup"
sudo useradd --system --no-create-home --user-group genieacs

echo "[+] Create directory"
mkdir /opt/genieacs
mkdir /opt/genieacs/ext
mkdir /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs
chown genieacs:genieacs /opt/genieacs/ext

echo "[+] Generating file genieacs.env"
cat > /opt/genieacs/genieacs.env <<EOF
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF
node -e "console.log(\"GENIEACS_UI_JWT_SECRET=\" + require('crypto').randomBytes(128).toString('hex'))" >> /opt/genieacs/genieacs.env

echo "[+] Autorization files"
sudo chown genieacs:genieacs /opt/genieacs/genieacs.env
sudo chmod 600 /opt/genieacs/genieacs.env

echo "[+] Create systemd genieacs-cwmp"
cat > /etc/systemd/system/genieacs-cwmp.service <<EOF
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

echo "[+] Create systemd genieacs-nbi"
cat > /etc/systemd/system/genieacs-nbi.service <<EOF
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi

[Install]
WantedBy=default.target
EOF

echo "[+] Create systemd genieacs-fs"
cat > /etc/systemd/system/genieacs-fs.service <<EOF
[Unit]
Description=GenieACS FS
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs

[Install]
WantedBy=default.target
EOF

echo "[+] Create systemd genieacs-ui"
cat > /etc/systemd/system/genieacs-ui.service <<EOF
[Unit]
Description=GenieACS UI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui

[Install]
WantedBy=default.target
EOF

echo "[+] Configure log file"
cat > /etc/logrotate.d/genieacs <<EOF
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

echo "[+] Start services"
sudo systemctl enable genieacs-cwmp
sudo systemctl start genieacs-cwmp
sudo systemctl status genieacs-cwmp

sudo systemctl enable genieacs-nbi
sudo systemctl start genieacs-nbi
sudo systemctl status genieacs-nbi

sudo systemctl enable genieacs-fs
sudo systemctl start genieacs-fs
sudo systemctl status genieacs-fs

sudo systemctl enable genieacs-ui
sudo systemctl start genieacs-ui
sudo systemctl status genieacs-ui
