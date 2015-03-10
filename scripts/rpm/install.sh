#!/bin/bash

# Configure the local machine to install packages built in this working directory


XAPIBASEURL=${PKG_REPO_LOCATION:-file://$PWD/RPMS/}
XAPISRCBASEURL=${SRC_REPO_LOCATION:-file://$PWD/SRPMS/}

sed \
    -e "s,@XAPIBASEURL@,${XAPIBASEURL},g" \
    -e "s,@XAPISRCBASEURL@,${XAPISRCBASEURL},g" \
    scripts/rpm/xapi.repo.in > scripts/rpm/install-repos.d/xapi.repo

for i in `ls scripts/rpm/install-repos.d/*.repo`; do
    install -m 0644 $i /etc/yum.repos.d/`basename $i`
done

yum update -y
yum -y install epel-release

yum repolist
yum install -y xenserver-core
