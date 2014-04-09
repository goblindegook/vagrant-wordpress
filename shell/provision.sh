#!/bin/bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations.

VAGRANT_DIR=/vagrant
PUPPET_DIR=/etc/puppet

# echo "Updating yum..."
# yum -q -y makecache
# yum -q -y update
# echo "Finished updating yum."

echo "Running" $(puppet help | grep 'Puppet v')
