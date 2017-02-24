# debian specific stuff
class mysql::server::debian inherits mysql::server::clientpackage {
  if $::operatingsystemmajrelease >= 9 {
    Package['mysql-server']{
      name  => 'mariadb-server',
    }
  }

  File['mysql_data_dir'] {
    path => '/var/lib/mysql',
  }

  file { 'mysql_debian_cnf':
    path    => '/etc/mysql/debian.cnf',
    notify  => Service['mysql'],
    owner   => root,
    group   => 0,
    mode    => '0600';
  }
}
