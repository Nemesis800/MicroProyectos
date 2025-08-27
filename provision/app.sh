#!/usr/bin/env bash
set -e

HOST_IP="$1"     # IP de la VM (app1/app2)
PORT="3000"      # Un solo servidor web por VM

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl jq unzip gpg

# Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# App 
mkdir -p /opt/web
cat >/opt/web/index.js <<'JS'
const Consul = require('consul');
const express = require('express');

const SERVICE_NAME='web';
const SCHEME='http';
const HOST=process.env.HOST||'127.0.0.1';
const PORT=parseInt(process.env.PORT||'3000',10);
const SERVICE_ID='m'+PORT;
const PID=process.pid;

const app=express();
const consul=new Consul();

app.get('/health',(req,res)=>res.end('Ok.'));
app.get('/',(req,res)=>{
  res.json({
    data: Math.floor(Math.random()*89999999+10000000),
    data_pid: PID, data_service: SERVICE_ID, data_host: HOST
  });
});
app.listen(PORT,()=>console.log(`Servicio iniciado en: ${SCHEME}://${HOST}:${PORT}!`));

const check={ id:SERVICE_ID, name:SERVICE_NAME, address:HOST, port:PORT,
  check:{ http:`${SCHEME}://${HOST}:${PORT}/health`, ttl:'5s', interval:'5s',
          timeout:'5s', deregistercriticalserviceafter:'1m' }};
consul.agent.service.register(check,(err)=>{ if(err) throw err; });
JS
cd /opt/web && npm install consul express

# Consul agent (cliente) que se une al server 192.168.56.13
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y && apt-get install -y consul

mkdir -p /etc/consul.d /var/lib/consul

cat >/etc/consul.d/client.hcl <<HCL
server = false
datacenter = "dc1"
node_name = "node-${HOST_IP}"
bind_addr = "${HOST_IP}"
advertise_addr = "${HOST_IP}"
client_addr = "0.0.0.0"
retry_join = ["192.168.56.13"]   # IP VM 'consul'
HCL

cat >/etc/systemd/system/consul.service <<'UNIT'
[Unit]
Description=Consul Client
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d -data-dir=/var/lib/consul
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now consul

# Node como servicio (1 sola instancia)
cat >/etc/systemd/system/nodeweb.service <<UNIT
[Unit]
Description=Node Web
After=network.target consul.service
[Service]
Environment=HOST=${HOST_IP}
Environment=PORT=${PORT}
ExecStart=/usr/bin/node /opt/web/index.js
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now nodeweb
echo "App en ${HOST_IP}:${PORT} registrada en Consul"