#!/usr/bin/bash

export LC_ALL=en_US.UTF-8
curdir=$(realpath .)

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

# Set rules as by defaault selinux is set to enforcing
# https://docs.pagure.org/koji/server_howto/#selinux-configuration
sudo setsebool -P httpd_can_network_connect_db=1 allow_httpd_anon_write=1
sudo chcon -R -t public_content_rw_t /mnt/koji/*

# Configure a koji build target
sudo -u kojiadmin koji add-tag dist-centos7
sudo -u kojiadmin koji add-tag --parent dist-centos7 --arches "x86_64" dist-centos7-build
sudo -u kojiadmin koji add-external-repo -t dist-centos7-build dist-centos7-repo http://mirror.centos.org/centos/7/os/\$arch/
sudo -u kojiadmin koji add-target dist-centos7 dist-centos7-build
sudo -u kojiadmin koji add-group dist-centos7-build build
sudo -u kojiadmin koji add-group dist-centos7-build srpm-build
sudo -u kojiadmin koji add-group-pkg dist-centos7-build build centos-release \
    bash bzip2 coreutils cpio diffutils findutils gawk gcc grep sed gcc-c++ \
    gzip info patch redhat-rpm-config rpm-build shadow-utils tar unzip \
    util-linux-ng which make
sudo -u kojiadmin koji add-group-pkg dist-centos7-build srpm-build bash \
    gnupg make redhat-rpm-config rpm-build shadow-utils wget rpmdevtools
sudo -u kojiadmin koji regen-repo dist-centos7-build

# Install the jobs scripts
# Assume Zuul have been previously installed on this node
# So the script below does not take this deps in account
cd $curdir
sudo ./koji-jobs/image/koji-client-base.sh
sudo ./install.sh

# Run scenario 1
./test-scenario_1.sh
