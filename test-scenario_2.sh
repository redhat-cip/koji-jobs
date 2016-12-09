#!/bin/bash

set -xe

my_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
hostname=$(hostname)
pkgname="p-$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)"

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@domain.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@domain.com

# Some clean up before
[ -d /tmp/workdir ] && rm -Rf /tmp/workdir
[ -d /tmp/repo ] && rm -Rf /tmp/repo
sudo yum remove -y p1

git init /tmp/repo
cat > /tmp/repo/p1.spec << EOF
Summary: A nice project p1 to test
Name: $pkgname
Version: 1.0
Release: 1
License: GPL
Source: http://$hostname/p1-1.0.tgz
Packager: John Doe <john@doe.com>

%description
What did you expect ?

%prep
%setup -q -n p1

%install
mkdir -p %{buildroot}/srv/p1
cp run_tests.sh %{buildroot}/srv/p1

%files
%attr(0755,root,root) /srv/p1
EOF
cd /tmp/repo/
git add p1.spec && git commit -m"Packing of p1"
# Simulate a bump to trigger the export
sed -i "s/Release: 1/Release: 2/" p1.spec
git add p1.spec && git commit -m"Bump of p1"

cd $my_path
sudo cp tests-data/*.tgz /var/www/html/

home=$HOME
[ ! -d $home/.koji ] && mkdir $home/.koji
for f in clientca.crt client.crt serverca.crt; do
    sudo cp /home/kojiadmin/.koji/$f $home/.koji/
done
sudo chown $USER:$USER $home/.koji/*

# Remove the package from a previous run if it exists
sudo -u kojiadmin koji remove-pkg dist-centos7 $pkgname || true

# Be sure p1 is tagged to in dist-centos7 for Koji to accept it
# to land (with non-scratch) build in that target
sudo -u kojiadmin koji add-pkg --owner kojiadmin dist-centos7 $pkgname

DEBUG=1 WORKSPACE=/tmp/workdir ZUUL_CHANGES=repo ZUUL_PROJECT=repo REPOS_CLONE_URL=file:///tmp \
    /var/lib/koji-jobs/pkg-export.sh dist-centos7

# Check the package is available in the target dist-centos7
sudo -u kojiadmin koji list-pkgs --tag dist-centos7
sudo -u kojiadmin koji list-pkgs --tag dist-centos7 | grep $pkgname
