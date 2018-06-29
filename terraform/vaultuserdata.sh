#!/bin/bash -v

# vaultuserdata.sh - script used to initialize vault server

yum update -y

# Install Vault
wget https://releases.hashicorp.com/vault/0.10.3/vault_0.10.3_linux_amd64.zip
unzip -j vault_*_linux_amd64.zip -d /usr/local/bin
# Install Consul
wget https://releases.hashicorp.com/consul/1.2.0/consul_1.2.0_linux_amd64.zip
unzip -j consul_*_linux_amd64.zip -d /usr/local/bin

# Add a user for the vault daemon
useradd -r -g daemon -d /usr/local/vault -m -s /sbin/nologin -c "Vault user" vault
# Add a user for the consul daemon
useradd -r -g daemon -d /usr/local/consul -m -s /sbin/nologin -c "Consul user" consul

# Create a vault config directory remove global access
mkdir /etc/vault /etc/ssl/vault
chown vault:root /etc/vault /etc/ssl/vault
chmod 750 /etc/vault /etc/ssl/vault
chmod 700 /usr/local/vault

# Write the vault config to file
cat <<EOF | sudo tee /etc/vault/config.hcl
ui = true
listener "tcp" {
	address = "0.0.0.0:8200"
	tls_disable = 1
	#tls_disable = 0
	#tls_cert_file = "/etc/ssl/vault/fullcert.pem"
	#tls_key_file = "/etc/ssl/vault/privkey.pem"
}
backend "consul" {
	address = "127.0.0.1:8500"
	path = "vault"
}
disable_mlock = true
EOF

# Create the vault startup script
cat <<EOF | sudo tee /usr/lib/systemd/system/vault.service
[Unit]
Description=Vault service
After=network-online.target

[Service]
User=vault
Group=daemon
PrivateDevices=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
SecureBits=keep-caps
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
KillSignal=SIGINT
TimeoutStopSec=30s
Restart=on-failure
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# Create the consul startup script
cat <<EOF | sudo tee /usr/lib/systemd/system/consul.service
[Unit]
Description=Consul service
After=network-online.target

[Service]
User=consul
Group=daemon
PrivateDevices=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only
SecureBits=keep-caps
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/consul agent -dev
KillSignal=SIGINT
TimeoutStopSec=30s
Restart=on-failure
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# Start the vault daemon
systemctl daemon-reload
systemctl start consul
systemctl enable consul
systemctl start vault
systemctl enable vault

# Check the vault server status
export VAULT_ADDR=http://127.0.0.1:8200
/usr/local/bin/vault status
