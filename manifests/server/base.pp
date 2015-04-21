# manage the common things of
# a mysql server
class mysql::server::base {
  package {'mysql-server':
    ensure => present,
  }
  file { 'mysql_main_cnf':
    path    => '/etc/mysql/my.cnf',
    source  => [
      "puppet:///modules/site_mysql/${::fqdn}/my.cnf",
      "puppet:///modules/site_mysql/my.cnf.${::operatingsystem}.${::operatingsystemmajrelease}",
      "puppet:///modules/site_mysql/my.cnf.${::operatingsystem}",
      'puppet:///modules/site_mysql/my.cnf',
      "puppet:///modules/mysql/config/my.cnf.${::operatingsystem}.${::operatingsystemmajrelease}",
      "puppet:///modules/mysql/config/my.cnf.${::operatingsystem}",
      'puppet:///modules/mysql/config/my.cnf'
    ],
    require => Package['mysql-server'],
    notify  => Service['mysql'],
    owner   => root,
    group   => 0,
    mode    => '0644';
  }

  file {
    'mysql_data_dir':
      ensure  => directory,
      path    => '/var/lib/mysql/data',
      require => Package['mysql-server'],
      before  => File['mysql_main_cnf'],
      owner   => mysql,
      group   => mysql,
      mode    => '0755';
    'mysql_setmysqlpass.sh':
      path    => '/usr/local/sbin/setmysqlpass.sh',
      source  => ["puppet:///modules/mysql/scripts/${::operatingsystem}/setmysqlpass.sh.${::operatingsystemmajrelease}",
                  "puppet:///modules/mysql/scripts/${::operatingsystem}/setmysqlpass.sh", ],
      require => Package['mysql-server'],
      owner   => root,
      group   => 0,
      mode    => '0500';
    'mysql_root_cnf':
      path    => '/root/.my.cnf',
      content => template('mysql/root/my.cnf.erb'),
      require => [ Package['mysql-server'] ],
      notify  => Exec['mysql_set_rootpw'],
      owner   => root,
      group   => 0,
      mode    => '0400';
  }

  exec { 'mysql_set_rootpw':
    command     => '/usr/local/sbin/setmysqlpass.sh',
    require     => [ File['mysql_setmysqlpass.sh'], Service['mysql'] ],
    # this is for security so that we only change the password
    # if the password file itself has changed
    refreshonly => true,
  }

  $backup_ensure = $mysql::server::backup_cron ? {
    true  => present,
    false => absent,
  }

  class { 'mysql::server::cron::backup': ensure => $backup_ensure }
  class { 'mysql::server::backup_helpers': ensure => $backup_ensure }

  $cron_ensure = $mysql::server::optimize_cron ? {
    true  => present,
    false => absent,
  }

  class { 'mysql::server::cron::optimize':
    ensure          => $cron_ensure,
    optimize_hour   => $mysql::server::optimize_hour,
    optimize_minute => $mysql::server::optimize_minute,
    optimize_day    => $mysql::server::optimize_day,
  }

  service { 'mysql':
    ensure    => running,
    enable    => true,
    hasstatus => true,
    require   => Package['mysql-server'],
  }

  file { '/etc/mysql/conf.d':
    ensure => directory,
    owner  => 'root',
    group  => 0,
    mode   => '0755',
  }

  if str2bool($::mysql_exists) {
    include mysql::server::account_security

    # Collect all databases and users
    Mysql_database<<| tag == "mysql_${::fqdn}" |>>
    Mysql_user<<| tag == "mysql_${::fqdn}" |>>
    Mysql_grant<<| tag == "mysql_${::fqdn}" |>>
  }

}
