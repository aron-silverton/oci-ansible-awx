#!/bin/bash

sed -i -r -e 's/\s+no$/ yes/g' /etc/yum/yum-cron*.conf
sed -i -r -e '/^autoinstall/s/no/yes/' /etc/uptrack/uptrack.conf


systemctl enable --now dbus.service
systemctl enable --now docker.service
systemctl enable --now firewalld.service
systemctl enable --now yum-cron.service

#uptrack-upgrade -y --all

# Install the proxyt transparent proxy client
wget http://kernel.us.oracle.com/~jhaxby/proxyt/repo/7/x86_64/proxyt-4.1.1-1.el7.x86_64.rpm
yum install ./proxyt-4.1.1-1.el7.x86_64.rpm -y
wget http://kernel.us.oracle.com/~jhaxby/proxyt/proxyt.repo
install -o root -g root -m 0644 proxyt.repo /etc/yum.repos.d/proxyt.repo
yum --disablerepo=* --enablerepo=proxyt makecache
yum update proxyt -y
#rm -f proxyt*

for service in http https
do
  # XXX Prevent terraform from prasing service variable by not using curly brace
  firewall-offline-cmd --zone=public --add-service=$service
done

systemctl restart firewalld.service

# Update pip or the cryptography pakckage may fail to install
/usr/bin/pip3 install --upgrade pip
/usr/bin/pip3 install --user --upgrade --disable-pip-version-check ansible

if [ ! -d ${GIT_CHECKOUT} ]
then
  git clone ${GIT_REPO} ${GIT_CHECKOUT}
fi
cd ${GIT_CHECKOUT}
git pull
git checkout tags/${GIT_TAG}

cd ${GIT_CHECKOUT}/installer
/root/.local/bin/ansible-playbook install.yml -i inventory -e @/root/awx.vars.yml

chmod +x /etc/cron.daily/docker-compose-pull

/etc/cron.daily/docker-compose-pull

