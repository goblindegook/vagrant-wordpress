# -*- mode: ruby -*-
# vi: set ft=ruby :

# https://github.com/dotless-de/vagrant-vbguest

require 'yaml'

dir = File.dirname( File.expand_path( __FILE__ ) )
vc  = YAML.load_file( "#{dir}/config.yaml" )

Vagrant.configure("2") do |config|

    # This box is provided by Puppet at http://puppet-vagrant-boxes.puppetlabs.com and
    # contains a CentOS 6.5 x64 release configured for Puppet. Once this box is downloaded
    # to your host computer, it is cached for future use under the specified box name.
    config.vm.box       = vc['vm']['box']
    config.vm.box_url   = vc['vm']['box_url']

    config.vm.hostname  = vc['vm']['hostname']

    # Vagrant Hosts Updater
    #
    # Automatically updates your hosts file. Add support to Vagrant by running:
    # 
    # $ vagrant plugin install vagrant-hostsupdater
    
    config.hostsupdater.remove_on_suspend = true
    config.hostsupdater.aliases           = vc['hosts']

    # Vagrant Puppet Librarian
    # 
    # Installs required puppet modules. Install plugin by running
    # 
    # $ vagrant plugin install vagrant-librarian-puppet
    
    config.librarian_puppet.puppetfile_dir = "puppet"

    # Default Box IP Address
    #
    # This is the IP address that your host will communicate to the guest through. In the
    # case of the default `192.168.50.4` that we've provided, VirtualBox will setup another
    # network adapter on your host machine with the IP `192.168.50.1` as a gateway.
    #
    # If you are already on a network using the 192.168.50.x subnet, this should be changed.
    # If you are running more than one VM through VirtualBox, different subnets should be used
    # for those as well. This includes other Vagrant boxes.
    config.vm.network :private_network, ip: vc['vm']['network']['private_network']['ip']

    if vc['vm']['forwarded_ports'] and !vc['vm']['forwarded_ports'].nil? and vc['vm']['forwarded_ports'].kind_of?(Array)
        vc['vm']['forwarded_ports'].each do |port|
            config.vm.network :forwarded_port, guest: port['guest'], host: port['host']
        end
    end

    # Drive mapping
    #
    # The following config.vm.synced_folder settings will map directories in your Vagrant
    # virtual machine to directories on your local machine. Once these are mapped, any
    # changes made to the files in these directories will affect both the local and virtual
    # machine versions. Think of it as two different ways to access the same file. When the
    # virtual machine is destroyed with `vagrant destroy`, your files will remain in your local
    # environment.
    
    if vc['vm']['synced_folders'] and !vc['vm']['forwarded_ports'].nil? and vc['vm']['synced_folders'].kind_of?(Array)
        vc['vm']['synced_folders'].each do |folder|
            config.vm.synced_folder folder['host'], folder['guest'], :type => folder['type'], :owner => folder['owner'], :mount_options => folder['mount_options']
        end
    end

    config.vm.usable_port_range = (10200..10500)

    # VirtualBox
    # 
    # VirtualBox provider customization.

    config.vm.provider :virtualbox do |virtualbox|
        virtualbox.customize [ "modifyvm", :id, "--natdnshostresolver1", "on" ]
        virtualbox.customize [ "modifyvm", :id, "--memory"             , vc['vm']['memory'] ]
        virtualbox.customize [ "modifyvm", :id, "--cpus"               , vc['vm']['cpus'] ]
        virtualbox.customize [ "modifyvm", :id, "--ioapic"             , vc['vm']['ioapic'] ]
    end

    # Provisioning
    #
    # Process one or more provisioning scripts depending on the existence of custom files.

    if File.exists?( File.join( dir, "shell", "provision.sh" ) ) then
        config.vm.provision :shell, :path => File.join( "shell", "provision.sh" )
    end

    # Puppet
    # 
    # Puppet options go here.

    config.vm.provision :puppet do |puppet|
        puppet.facter = {
            "ssh_username" => "vagrant"
        }
        puppet.manifests_path       = 'puppet/manifests'
        puppet.manifest_file        = 'default.pp'
        puppet.module_path          = 'puppet/modules'
        puppet.synced_folder_type   = 'nfs'
        puppet.options = [
            '--verbose',
            '--hiera_config /vagrant/puppet/hiera.yaml',
            '--templatedir /vagrant/puppet/templates',
            '--parser future',
        ]
    end

    # SSH
    # 
    # SSH forward agent and keep-alive.

    config.ssh.forward_agent    = vc['vm']['ssh']['forward_agent']
    config.ssh.forward_x11      = vc['vm']['ssh']['forward_x11']
    config.ssh.keep_alive       = vc['vm']['ssh']['keep_alive']
    config.ssh.shell            = vc['vm']['ssh']['shell']

end

