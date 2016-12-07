#!/usr/bin/bash

sudo yum -y install epel-release
sudo yum -y install git ansible

git clone https://github.com/kostyrevaa/ansible-koji-infra
cd ansible-koji-infra

hostname=$(hostname)

cat > hosts << EOF
[koji_db]
$hostname ansible_connection=local
[koji_ca]
$hostname ansible_connection=local
[koji_hub]
$hostname ansible_connection=local
[koji_web]
$hostname ansible_connection=local
[koji_builder]
$hostname ansible_connection=local
EOF

sudo ./bootstrap-ansible.sh
sudo ansible-playbook -i hosts site.yml
sudo -u kojiadmin koji moshimoshi
