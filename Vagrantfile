# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # ========== LB: solo HAProxy ==========
  config.vm.define "lb" do |lb|
    lb.vm.box = "bento/ubuntu-22.04"
    lb.vm.hostname = "lb"
    lb.vm.network :private_network, ip: "192.168.56.10"
    lb.vm.network :forwarded_port, guest: 80,   host: 8080, auto_correct: true   # HAProxy
    lb.vm.network :forwarded_port, guest: 8404, host: 8404, auto_correct: true   # Stats GUI
    lb.vm.provision "shell", path: "provision/lb.sh"
  end

  # ========== Consul server en VM separada ==========
  config.vm.define "consul" do |c|
    c.vm.box = "bento/ubuntu-22.04"
    c.vm.hostname = "consul"
    c.vm.network :private_network, ip: "192.168.56.13"
    c.vm.network :forwarded_port, guest: 8500, host: 8500, auto_correct: true    # Consul UI
    c.vm.provision "shell", path: "provision/consul.sh"
  end

  # ========== APP1 ==========
  config.vm.define "app1" do |app|
    app.vm.box = "bento/ubuntu-22.04"
    app.vm.hostname = "app1"
    app.vm.network :private_network, ip: "192.168.56.11"
    app.vm.provision "shell", path: "provision/app.sh", args: "192.168.56.11"
  end

  # ========== APP2 ==========
  config.vm.define "app2" do |app|
    app.vm.box = "bento/ubuntu-22.04"
    app.vm.hostname = "app2"
    app.vm.network :private_network, ip: "192.168.56.12"
    app.vm.provision "shell", path: "provision/app.sh", args: "192.168.56.12"
  end
end