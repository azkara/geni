#!/usr/bin/env bash

set -e
set -u

if [[ ! -f /etc/debian_version ]]
then
    echo "Script only tested in Debian"
    exit 1
else
    if ! grep -qE '^10' /etc/debian_version
    then
        echo "Script only tested in Debian Buster"
        exit 1
    fi
fi

if [[ "$EUID" -ne 0 ]]
then
    echo "Please run as root"
    exit 1
fi

echo "Read through the script before running it."
read -rp "Are you shure you want to continue? [y/N]: " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]
then
    echo "Starting the installation"
else
    echo "Aborting the installation"
    exit 0
fi

apt-get update -qq
apt-get upgrade -qq
apt-get install gnupg -qq

wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -

cat << EOF > /etc/apt/sources.list.d/mongodb-org-4.4.list
deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main
EOF

wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -

cat << EOF > /etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/node_14.x buster main
EOF

apt-get update -qq
apt-get install nodejs mongodb-org -qq

npm install -g --unsafe-perm --quiet --no-progress genieacs

useradd --system --no-create-home --user-group genieacs
mkdir -p /opt/genieacs/ext
chown genieacs:genieacs /opt/genieacs/ext

cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c"${1:-20}")
GENIEACS_CWMP_IGNORE_CONNECTION_REQUEST_CREDENTIALS=true
EOF

chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

mkdir /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

cat << EOF > /etc/systemd/system/genieacs-cwmp.service
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

cat << EOF > /etc/systemd/system/genieacs-nbi.service
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

cat << EOF > /etc/systemd/system/genieacs-fs.service
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

cat << EOF > /etc/systemd/system/genieacs-ui.service
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

cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

systemctl enable mongod.service
systemctl start mongod.service

systemctl enable genieacs-cwmp
systemctl start genieacs-cwmp

systemctl enable genieacs-nbi
systemctl start genieacs-nbi

systemctl enable genieacs-fs
systemctl start genieacs-fs

systemctl enable genieacs-ui
systemctl start genieacs-ui

sleep 4

systemctl status --no-pager mongod.service
systemctl status --no-pager genieacs-cwmp
systemctl status --no-pager genieacs-nbi
systemctl status --no-pager genieacs-fs
systemctl status --no-pager genieacs-ui

echo

ss -pln sport 27017 or sport 3000 or sport 7547 or sport 7557 or sport 7567 or sport 3478