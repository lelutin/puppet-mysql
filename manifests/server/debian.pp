# debian specific stuff
class mysql::server::debian inherits mysql::server::clientpackage {
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
