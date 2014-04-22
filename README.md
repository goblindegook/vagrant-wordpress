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

**NB:** If you obtained these Vagrant files from a Git repository, you'll have to rename the (hidden) _.git_ directory at the root, otherwise your development environment will be unable to check out the projects you'll be working on.

## Running the development environment

You are now ready to launch the virtual machine by typing:

```
$ vagrant up
```

`vagrant up` will download and setup your development environment from scratch when you run it for the first time.

On first run, Vagrant will pull a CentOS 6.5 box and install critical services required by WordPress, including Nginx (a high-performance web server), PHP-FPM (a FastCGI process manager for the PHP language) and MariaDB (a drop-in replacement for the MySQL relational database management system).  This can be a lengthy process, around 30-60 minutes, so find something else to do while you wait.

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
* _puppet/manifests/default.pp_: Main Puppet configuration manifest.
* _puppet/templates/*_: Contains templates for several configuration files used by the virtual machine.
* _puppet/hiera.yaml_: Sets options for Puppet's hierarchical datastore used to maintain a catalogue of installed and configured componentes.

If you alter any of these files, you will have to reprovision the development environment so your changes are applied. You don't need to recreate the virtual machine from zero, simply run the following command:

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

## Command line tools

You will also find a few helpful CLI tools inside your development environment (access with `vagrant ssh`):

* [ack](http://beyondgrep.com/): A fast tool for grepping code.
* [Bower](http://bower.io/): A package manager for the web.
* [Composer](https://getcomposer.org/): A dependency manager for PHP.
* [Grunt](http://gruntjs.com/): JavaScript-based task automation.
* [makepot](https://codex.wordpress.org/I18n_for_WordPress_Developers): POT file generator for WordPress internationalization.
* [PHP CodeSniffer](http://pear.php.net/package/PHP_CodeSniffer/): Detects coding standard violations in PHP, JavaScript and CSS files. Includes a set of [WordPress coding standards](https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards).
* [phpcov](https://github.com/sebastianbergmann/phpcov): A PHP code coverage report generator.
* [phpcpd](https://github.com/sebastianbergmann/phpcpd): A PHP copy-paste detector.
* [phpdcd](https://github.com/sebastianbergmann/phpdcd): A PHP dead code detector.
* [phpDocumentor](http://www.phpdoc.org/): Documentation generator for PHP.
* [phploc](https://github.com/sebastianbergmann/phploc): Measures the size of a PHP project.
* [PHPMD](http://phpmd.org/): A PHP Mess Detector.
* [PHPUnit](http://phpunit.de/): PHP unit testing framework.
* [WP-CLI](http://wp-cli.org/): Manage WordPress from the command line.
* [Yeoman](http://yeoman.io/): Scaffolding tool for web projects.

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
