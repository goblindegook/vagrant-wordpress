# WordPress Development Environment

## Before you begin

First of all, make sure the following components are installed:

* [Vagrant](http://www.vagrantup.com/)
* [VirtualBox](https://www.virtualbox.org/)
* VirtualBox Extension Pack

Then, open a terminal on the folder where _Vagrantfile_ resides, and install the `hostsupdater` and `puppet-librarian` plugins by typing into the prompt:

```
$ vagrant plugin install vagrant-hostsupdater
$ vagrant plugin install vagrant-puppet-librarian
```

**NB:** If you obtained these Vagrant files from a Git repository, you'll have to delete or rename the (hidden) _.git_ directory at the root, otherwise your development environment will be unable to check out the projects you'll be working on.

## Running the development environment

You are now ready to launch the virtual machine by typing:

```
$ vagrant up
```

`vagrant up` will download and setup all your development environment when you run it for the first time.  This can be a lengthy process, around 30-60 minutes, so find something else to do while you wait.

Whenever you want to stop working, you may shut down the development environment using:

```
$ vagrant halt
```

There are a few more Vagrant commands that you can use, please [refer to the documentation][Vagrant CLI Documentation].

[Vagrant CLI Documentation]: https://docs.vagrantup.com/v2/cli/index.html

## Configuration

Common settings for the development virtual machine may be applied by editing the _config.yaml_ file found in the same directory as this README document.

Advanced settings and workflows may require editing the Vagrant and Puppet files found at the following locations:

* _Vagrantfile_: Contains settings for Vagrant to download and set up the virtual machine.
* _shell/provision.sh_: This shell script will be run whenever a virtual machine is provisioned, either on creation or by explicitly running `vagrant provision`.
* _puppet/manifests/init.pp_: Main Puppet configuration manifest.
* _puppet/templates/*_: Contains templates for several configurations files used by the virtual machine.
* _puppet/hiera.yaml_: Sets options for Puppet's hierarchical datastore used to maintain a catalogue of installed and configured componentes.

If you alter any of these files, you will need to reprovision the development environment so your changes are applied. You don't need to recreate the virtual machine from scratch, simply run the following command:

```
$ vagrant provision
```

## Installed applications

The following applications and services are provided by the virtual machine.  URLs and passwords are those configured by default and may be changed in _config.yaml_.

| Application                  | Username       | Password |
| ---------------------------- | -------------- | -------- |
| [WordPress][]                | admin          | admin    |
| [WordPress Development][]    | admin          | admin    |
| MariaDB                      | root           | vagrant  |
| ↳ `wordpress`                | wordpress      | vagrant  |
| ↳ `wordpress_dev`            | wordpress_dev  | vagrant  |
| ↳ `wordpress_test`           | wordpress_test | vagrant  |
| [phpMyAdmin][]               | root           | vagrant  |
| [phpMemcachedAdmin][]        |                |          |
| [Couchbase][]                | Administrator  | password |
| [ElasticSearch BigDesk][]    |                |          |
| [ElasticSearch Inquisitor][] |                |          |
| [ElasticSearch Head][]       |                |          |
| [ElasticSearch HQ][]         |                |          |
| [Webgrind][]                 |                |          |

[WordPress]:                http://wordpress.local/wp-admin/
[WordPress Development]:    http://develop.wordpress.local/wp-admin/
[phpMyAdmin]:               http://wpdev/phpMyAdmin/
[phpMemcachedAdmin]:        http://wpdev/phpMemcachedAdmin/
[Couchbase]:                http://wpdev:8091/
[ElasticSearch BigDesk]:    http://wordpress.local:9200/_plugin/BigDesk/
[ElasticSearch Inquisitor]: http://wordpress.local:9200/_plugin/inquisitor/
[ElasticSearch Head]:       http://wordpress.local:9200/_plugin/head/
[ElasticSearch HQ]:         http://wordpress.local:9200/_plugin/HQ/
[Webgrind]:                 http://wordpress.local/webgrind/

## Port reference

The following ports are exposed by the development virtual machine.

| Port  | Description                                |
| ----: | ------------------------------------------ |
| 22    | SSH2                                       |
| 80    | Nginx HTTP                                 |
| 443   | Nginx HTTPS                                |
| 8091  | Couchbase Web Administration               |
| 8092  | Couchbase API                              |
| 9000  | Xdebug DBGp                                |
| 9200  | ElasticSearch API                          |
| 11211 | Couchbase Memcached API (Couchbase bucket) |
| 11212 | Couchbase Memcached API (Memcached bucket) |
