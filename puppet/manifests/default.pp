Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }

#
# Time and date
#

ensure_packages( [ 'tzdata' ] )

class { 'ntp': }

$localtime = hiera( 'timezone' )

file { '/etc/localtime':
    ensure  => link,
    target  => "/usr/share/zoneinfo/${localtime}",
    require => Package['tzdata'],
}

#
# Users and groups
#

group { 'puppet':   ensure => present }
group { 'www-data': ensure => present }
group { 'mysql':    ensure => present }

user { ['apache', 'nginx', 'httpd', 'www-data']:
    shell   => '/bin/bash',
    ensure  => present,
    groups  => 'www-data',
    require => Group['www-data'],
}

user { 'mysql':
    ensure  => present,
    groups  => 'mysql',
    require => Group['mysql'],
}

#
# Setup yum repositories
#

class { 'yum': extrarepo => [ 'epel' ] }
class { 'yum::repo::rpmforge': }
class { 'yum::repo::repoforgeextras': }
class { 'yum::repo::remi': }
class { 'yum::repo::remi_php55': }

yumrepo { 'MariaDB':
    descr       => 'MariaDB',
    baseurl     => 'http://yum.mariadb.org/10.0/centos6-amd64',
    gpgkey      => 'https://yum.mariadb.org/RPM-GPG-KEY-MariaDB',
    gpgcheck    => 1,
    enabled     => 1,
}

yumrepo { 'Couchbase':
    descr       => 'Couchbase package repository',
    baseurl     => 'http://packages.couchbase.com/rpm/6.2/x86_64',
    gpgkey      => 'http://packages.couchbase.com/rpm/couchbase-rpm.key',
    gpgcheck    => 1,
    enabled     => 1,
}

Class['::yum'] -> Yum::Managed_yumrepo <| |> -> Package <| |>

#
# Install packages
#

$packages = hiera( 'packages' )

if is_array( $packages['yum'] ) and count( $packages['yum'] ) > 0 {
    package { $packages['yum']:
        ensure  => latest,
        require => [
            Class['yum'],
            Class['yum::repo::rpmforge'],
            Class['yum::repo::repoforgeextras'],
            Class['yum::repo::remi'],
            Class['yum::repo::remi_php55'],
        ],
    }
}

if is_hash( $packages['rpm'] ) and count( $packages['rpm'] ) > 0 {
    $packages['rpm'].each |$name, $source| {
        package { $name:
            provider    => 'rpm',
            source      => $source,
            ensure      => installed,
        }
    }
}

#
# Setup hosts
#

host { hiera( 'hosts' ):
    ip => '127.0.0.1',
}

#
# Setup firewall
#

class fw::pre {
    Firewall {
        require => undef,
    }

    firewall { '000 accept all icmp':
        proto   => 'icmp',
        action  => 'accept',
    }->
    firewall { '001 accept all to lo interface':
        proto   => 'all',
        iniface => 'lo',
        action  => 'accept',
    }->
    firewall { '002 accept related established rules':
        proto   => 'all',
        ctstate => ['RELATED', 'ESTABLISHED'],
        action  => 'accept',
    }->
    firewall { '010 accept all ssh':
        port    => [ 22, 2222 ],
        action  => 'accept',
    }
}

class fw::post {
    Firewall {
        require => undef,
    }
}

resources { "firewall":
    purge => true,
}
Firewall {
    before  => Class['fw::post'],
    require => Class['fw::pre'],
}
class { [ 'fw::pre', 'fw::post' ]: }
class { 'firewall': }

#
# Node.js packages
#

class { 'nodejs':
    version => 'stable',
}

package { $packages['npm']:
    provider => npm,
    require  => Class['nodejs'],
}

#
# MariaDB
#

$mariadb = hiera( 'mariadb' )

file { "/var/run/mysqld":
    ensure  => "directory",
    owner   => "mysql",
    group   => "mysql",
    mode    => 770,
    require => [ User['mysql'], Group['mysql'] ],
}

class {
    'mysql::server':
    package_name    => 'MariaDB-server',
    require         => [ Yumrepo['MariaDB'], User['mysql'], Group['mysql'] ],
    service_name    => 'mysql',
    root_password   => $mariadb['root_password']
    ;
    'mysql::client':
    package_name    => 'MariaDB-client',
    require         => Yumrepo['MariaDB'],
    ;
}

define mariadb_db (
    $user,
    $password,
    $host     = 'localhost',
    $grant    = [],
    $sql      = false,
    $vcsrepo  = false,
) {
    if $name == '' or $password == '' {
        fail( 'Configuration error: user and password are required to create MariaDB databases.' )
    }

    if $vcsrepo {
        $require = Vcsrepo[$vcsrepo]
    }

    mysql::db { $name:
        user     => $user,
        password => $password,
        host     => $host,
        grant    => $grant,
        sql      => $sql,
        require  => $require,
    }
}

if is_hash( $mariadb['databases'] ) and count( $mariadb['databases'] ) > 0 {
    create_resources( mariadb_db, $mariadb['databases'] )
}

#
# Nginx
#

$phpfpm = hiera( 'php-fpm' )
$nginx  = hiera( 'nginx' )

$php_fpm_sock        = $phpfpm['php_fpm_sock']
$fastcgi_pass        = $phpfpm['fastcgi_pass']
$fastcgi_param_parts = $phpfpm['fastcgi_param_parts']

exec { "${php_fpm_sock}":
	command => "touch ${php_fpm_sock} && chmod 777 ${php_fpm_sock}",
	onlyif  => ["test ! -f ${php_fpm_sock}", "test ! -f ${php_fpm_sock}="],
	require => Package['nginx'],
}

file { '/etc/php-fpm.d/www.conf':
    ensure  => file,
    path    => '/etc/php-fpm.d/www.conf',
    content => template('/vagrant/puppet/templates/php-fpm/www.conf.erb'),
    notify  => [
        Class['nginx::service'],
        Service['php-fpm'],
    ],
    require => Exec["${php_fpm_sock}"],
}

class { 'nginx':
    worker_processes    => $nginx['worker_processes'],
    worker_connections  => $nginx['worker_connections'],
    nginx_error_log     => $nginx['nginx_error_log'],
    http_access_log     => $nginx['http_access_log'],
    server_tokens       => $nginx['server_tokens'],
    gzip                => $nginx['gzip'],
    http_cfg_append     => $nginx['http_cfg_append'],
    service_ensure      => running,
}

#
# Nginx Vhosts
#

$nginx['vhosts'].each |$name, $vhost| {

    file { "/etc/nginx/sites-available/${name}":
        ensure  => file,
        path    => "/etc/nginx/sites-available/${name}",
        content => template($vhost['template']),
        require => [
            Package['nginx'],
        ],
    }

    if $vhost['vcsrepo'] {
        $require = [
            File["/etc/nginx/sites-available/${name}"],
            Vcsrepo[$vhost['vcsrepo']],
        ]
    } else {
        $require = [
            File["/etc/nginx/sites-available/${name}"],
        ]
    }

    file { "/etc/nginx/sites-enabled/${name}":
        ensure  => link,
        path    => "/etc/nginx/sites-enabled/${name}",
        target  => "/etc/nginx/sites-available/${name}",
        require => $require,
        notify  => [
            Service['nginx'],
            Service['php-fpm'],
        ],
    }

    file { "${vhost['root']}/../logs":
        ensure  => directory,
        require => [
            File["/etc/nginx/sites-enabled/${name}"],
        ],
        notify  => [
            Service['nginx'],
            Service['php-fpm'],
        ],
    }
}

#
# PHP
#

Class['Php'] -> Class['Php::Devel'] -> Php::Module <| |> -> Php::Pear::Module <| |> -> Php::Pecl::Module <| |>

class {
    'php':
	package             => 'php-fpm',
  	service             => 'php-fpm',
  	service_autorestart => false,
  	config_file         => '/etc/php.ini',
    ;
    'php::devel':
    ;
}

Package <| |>
->
file { '/var/lib/php/session':
    ensure  => directory,
    group   => 'www-data',
    mode    => '770',
    require => [ Group['www-data'], Package['php-fpm'] ],
}

# Configure PHP and its packages

ensure_packages( [ 'augeas' ] )

$php = hiera('php')

if is_hash( $php ) and count( $php ) > 0 {
    keys( $php ).each |$package| {

        if $package == 'ini' {
            $defaults = {
                'notify'  => Service['php-fpm'],
                'require' => [ Package['php'], Package['php-fpm'] ],
            }
        } else {
            $defaults = {
                'target'  => "/etc/php.d/${package}.ini",
                'require' => Package["php-pecl-${package}"],
                'notify'  => Service['php-fpm'],
            }
        }

        if is_hash( $php[$package] ) and count( $php[$package] ) > 0 {
            create_resources( php::augeas, $php[$package], $defaults )
        }
    }
}

service { 'php-fpm':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['php-fpm'],
}

if is_array( $packages['php'] ) and count( $packages['php'] ) > 0 {
    php::module { $packages['php']:
    	service_autorestart => true,
    }
}

if is_array( $packages['pecl'] ) and count( $packages['pecl'] ) > 0 {
    php::pecl::module { $packages['pecl']:
        use_package         => false,
        service_autorestart => true,
    }
}

php::pear::module {
    'PHP_CodeSniffer':
	use_package         => false,
	service_autorestart => true,
	alldeps 			=> true,
    ;
    'phpDocumentor':
    use_package         => false,
    service_autorestart => true,
    repository          => 'pear.phpdoc.org',
    alldeps             => true,
    ;
    [ 'PHPUnit', 'phploc', 'phpcpd', 'phpcov' ]:
	use_package         => false,
	service_autorestart => true,
	repository  		=> 'pear.phpunit.de',
	alldeps 			=> true,
    ;
    'PHP_PMD':
    use_package         => false,
    service_autorestart => true,
    repository          => 'pear.phpmd.org',
    alldeps             => true,
    ;
}

class { 'composer':
	target_dir      => '/usr/local/bin',
	composer_file   => 'composer',
	download_method => 'curl',
	logoutput       => false,
	tmp_path        => '/tmp',
	php_package     => "php-cli",
	curl_package    => 'curl',
	suhosin_enabled => false,
}

# Create Xdebug profiler path

$xdebug_profiler_output_dir = $php['xdebug']['xdebug_profiler_output_dir']['value']

if $xdebug_profiler_output_dir and is_string( $xdebug_profiler_output_dir ) {
    file { $xdebug_profiler_output_dir:
        ensure  => directory,
        before  => Package['php-pecl-xdebug'],
    }
}

#
# Clone projects
#

$vcs = hiera('vcs')

file { '/root/.ssh':
    ensure  => directory,
    mode    => '700',
}

file { '/root/.ssh/known_hosts':
    ensure  => file,
    source  => '/vagrant/puppet/templates/home/.ssh/known_hosts',
    mode    => '600',
    require => File['/root/.ssh'],
}

file { '/home/vagrant/.ssh':
    ensure  => directory,
    mode    => '700',
    owner   => 'vagrant',
    group   => 'vagrant',
}

file { '/home/vagrant/.ssh/known_hosts':
    ensure  => file,
    source  => '/vagrant/puppet/templates/home/.ssh/known_hosts',
    mode    => '600',
    owner   => 'vagrant',
    group   => 'vagrant',
    require => File['/home/vagrant/.ssh'],
}

$vcs['clone'].each |$repo| {
    vcsrepo { $repo['path']:
        source      => $repo['source'],
        ensure      => latest,
        provider    => $repo['provider'],
        require     => File['/root/.ssh/known_hosts'],
    }
}

#
# WordPress Config
#

$wordpress = hiera('wordpress')

$wordpress.each |$name, $wp| {

    $db = $mariadb['databases'][$wp['dbname']]

    $extra_php = template('/vagrant/puppet/templates/wordpress/wp-config.php.erb')
    
    Exec["wp core config ${name}"] -> Exec["wp core install ${name}"]

    file { "${wp['vcsrepo']}/wp-tests-config.php":
        ensure  => file,
        content => template('/vagrant/puppet/templates/php-fpm/wp-tests-config.php.erb'),
        notify  => [
            Class['nginx::service'],
            Service['php-fpm'],
        ],
        require     => [
            Vcsrepo[$wp['vcsrepo']],
        ],
    }

    exec { "wp core config ${name}":
        command     => "wp core config --dbname=${wp['dbname']} --dbuser=${db['user']} --dbpass=${db['password']} --dbhost=${db['host']} --extra-php ${extra_php}",
        cwd         => "${wp['vcsrepo']}/src",
        require     => [
            File['/usr/bin/wp'],
            Vcsrepo[$wp['vcsrepo']],
            Mysql::Db[$wp['dbname']],
        ],
        logoutput   => true,
    }

    exec { "wp core install ${name}":
        command     => "wp core install --url=${wp['url']} --title=\"${wp['title']}\" --admin_name=\"${wp['admin_name']}\" --admin_email=\"${wp['admin_email']}\" --admin_password=\"${wp['admin_password']}\" --allow-root",
        cwd         => "${wp['vcsrepo']}/src",
        require     => [
            File['/usr/bin/wp'],
        ],
        logoutput   => true,
    }

}


#
# WordPress tools and additions
#

# WordPress Standards for CodeSniffer

vcsrepo { '/usr/share/pear/PHP/CodeSniffer/Standards/WordPress':
    # TODO: /usr/share/pear should be read from $(pear config-get php_dir)
    source      => 'git://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards.git',
    ensure      => present,
    provider    => git,
    require     => Php::Pear::Module['PHP_CodeSniffer'],
}

# WP-CLI

exec{ 'wp-cli download':
    command => "curl -o /usr/bin/wp -L https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar",
    require => Package[ 'curl' ],
    creates => "/usr/bin/wp"
}

file { "/usr/bin/wp":
    ensure  => present,
    mode    => "a+x",
    require => Exec[ 'wp-cli download' ]
}

# WordPress i18n Tools

vcsrepo { '/opt/wordpress':
    source      => 'http://develop.svn.wordpress.org/trunk/',
    path        => '/opt/wordpress',
    ensure      => present,
    provider    => svn,
}

file_line { 'alias add-textdomain':
    ensure  => present,
    line    => "alias add-textdomain='php /opt/wordpress/tools/i18n/add-textdomain.php'",
    path    => "/home/vagrant/.bash_aliases",
    require => [ Vcsrepo["/opt/wordpress"], Package['php-cli'] ],
}

file_line { 'alias makepot':
    ensure  => present,
    line    => "alias makepot='php /opt/wordpress/tools/i18n/makepot.php'",
    path    => "/home/vagrant/.bash_aliases",
    require => [ Vcsrepo["/opt/wordpress"], Package['php-cli'] ],
}

# WPScan



#
# Home
#

exec { 'dotfiles':
    cwd     => "/home/vagrant",
    command => "cp -r /vagrant/puppet/templates/home/.[a-zA-Z0-9]* /home/vagrant/ && chown -R vagrant /home/vagrant/.[a-zA-Z0-9]* ",
    onlyif  => 'test -d /vagrant/puppet/templates/home',
    returns => [0, 1],
}

file_line { 'include ~/.bash_aliases':
    ensure  => present,
    line    => 'if [ -f ~/.bash_aliases ] ; then source ~/.bash_aliases; fi',
    path    => "/home/vagrant/.bash_profile",
    require => Exec['dotfiles']
}

exec { 'bash_git':
    cwd     => "/home/vagrant",
    command => "curl https://raw.github.com/git/git/master/contrib/completion/git-prompt.sh > /home/vagrant/.bash_git",
    creates => "/home/vagrant/.bash_git",
}

file_line { 'include ~/.bash_git':
    ensure  => present,
    line    => 'if [ -f ~/.bash_git ] ; then source ~/.bash_git; fi',
    path    => "/home/vagrant/.bash_profile",
    require => Exec['bash_git']
}

#
# Couchbase
#

$couchbase = hiera('couchbase')

exec { "couchbase-node-init":
    path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
    command     => "couchbase-cli node-init -c localhost:8091 -u ${couchbase['username']} -p ${couchbase['password']}",
    creates     => '/opt/couchbase/var/lib/couchbase/couchbase-server.node',
    require     => Package['couchbase-server'],
    logoutput   => true,
}


exec { "couchbase-cluster-init":
    path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
    command     => "couchbase-cli cluster-init -c localhost:8091 --cluster-init-username=${couchbase['username']} --cluster-init-password=${couchbase['password']} --cluster-init-ramsize=256 -u ${couchbase['username']} -p ${couchbase['password']}",
    # creates     => '/opt/couchbase/var/lib/couchbase/remote_clusters_cache_v2',
    require     => Exec['couchbase-node-init'],
    logoutput   => true,
    tries       => 5,
    try_sleep   => 10,
    # refreshonly => true,
}

exec { "bucket-create-default":
    path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
    command     => "couchbase-cli bucket-create -c localhost:8091 -u ${couchbase['username']} -p ${couchbase['password']} --bucket=default --bucket-type=couchbase --bucket-ramsize=128 --bucket-port=11211 --bucket-replica=0 --enable-flush=0 --bucket-password=''",
    unless      => "couchbase-cli bucket-list -c localhost -u ${couchbase['username']} -p ${couchbase['password']} | grep ^default",
    require     => Exec['couchbase-cluster-init'],
    returns     => [0, 2],
    logoutput   => true,
}

exec { "bucket-create-memcached":
    path        => ['/opt/couchbase/bin', '/usr/bin', '/bin', '/sbin', '/usr/sbin' ],
    command     => "couchbase-cli bucket-create -c localhost:8091 -u ${couchbase['username']} -p ${couchbase['password']} --bucket=memcached --bucket-type=memcached --bucket-ramsize=128 --bucket-port=11212 --bucket-replica=0 --enable-flush=0 --bucket-password=''",
    unless      => "couchbase-cli bucket-list -c localhost -u ${couchbase['username']} -p ${couchbase['password']} | grep ^memcached",
    require     => Exec['couchbase-cluster-init'],
    returns     => [0, 2],
    logoutput   => true,
}

#
# ElasticSearch
#

create_resources( 'class', {
    'elasticsearch' => {
        'package_url'   => 'https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.0.noarch.rpm',
        'java_install'  => true,
        'autoupgrade'   => true,
    },
} )

# Install ElasticSearch plugins

exec { 'elasticsearch-plugin-install_bigdesk':
    command     => '/usr/share/elasticsearch/bin/plugin -install lukas-vlcek/bigdesk',
    creates     => '/usr/share/elasticsearch/plugins/bigdesk',
    require     => Class['elasticsearch'],
    returns     => [0, 74],
}

exec { 'elasticsearch-plugin-install_elasticsearch-HQ':
    command     => '/usr/share/elasticsearch/bin/plugin -install royrusso/elasticsearch-HQ',
    creates     => '/usr/share/elasticsearch/plugins/HQ',
    require     => Class['elasticsearch'],
    returns     => [0, 74],
}

exec { 'elasticsearch-plugin-install_head':
    command     => '/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head',
    creates     => '/usr/share/elasticsearch/plugins/head',
    require     => Class['elasticsearch'],
    returns     => [0, 74],
}

exec { 'elasticsearch-plugin-install_inquisitor':
    command     => '/usr/share/elasticsearch/bin/plugin -install polyfractal/elasticsearch-inquisitor',
    creates     => '/usr/share/elasticsearch/plugins/inquisitor',
    require     => Class['elasticsearch'],
    returns     => [0, 74],
}

#
# Firewall
#

# Accept Nginx on TCP ports 80 and 443
firewall { '050 accept all http and https':
    port   => [ 80, 443 ],
    proto  => tcp,
    action => accept,
}

# Accept MariaDB on TCP port 3306
firewall { '060 accept all mysql':
    port   => 3306,
    proto  => tcp,
    action => accept,
}

# Accept Couchbase on TCP ports 8091 and 8092
firewall { '080 ACCEPT tcp/8091,8092':
    port   => [ 8091, 8092 ],
    proto  => tcp,
    action => accept,
}

# Accept Xdebug on TCP port 9000
firewall { '080 ACCEPT tcp/9000':
    port   => [ 9000 ],
    proto  => tcp,
    action => accept,
}

# Accept ElasticSearch on TCP ports 9200 and 9300
firewall { '080 ACCEPT tcp/9200,9300':
    port   => [ 9200, 9300 ],
    proto  => tcp,
    action => accept,
}

#
# Applications
#

# phpMyAdmin

file { '/usr/share/nginx/html/phpMyAdmin':
    ensure  => link,
    target  => "/usr/share/phpMyAdmin",
    require => Package['phpMyAdmin'],
}

# phpMemcacheAdmin

file { '/usr/share/nginx/html/phpMemcachedAdmin':
    ensure  => link,
    target  => "/usr/share/phpMemcachedAdmin",
    require => Package['phpMemcachedAdmin'],
}

# Webgrind

puppi::netinstall { 'netinstall-webgrind':
    url                 => 'https://webgrind.googlecode.com/files/webgrind-release-1.0.zip',
    destination_dir     => '/opt',
    extracted_dir       => 'webgrind',
    postextract_command => 'ln -s /opt/webgrind /usr/share/nginx/html/webgrind',
    require             => [ Package['php-pecl-xdebug'], Class['nginx'] ],
}
