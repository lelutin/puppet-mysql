# optimize mysql databases regurarely
class mysql::server::cron::optimize (
  $optimize_hour,
  $optimize_minute,
  $optimize_day
) {

  file { 'mysql_optimize_script':
    path    => '/usr/local/sbin/optimize_mysql_tables.rb',
    source  => 'puppet:///modules/mysql/scripts/optimize_tables.rb',
    owner   => root,
    group   => 0,
    mode    => '0700';
  }

  cron { 'mysql_optimize_cron':
    command => '/usr/local/sbin/optimize_mysql_tables.rb',
    user    => 'root',
    minute  => $optimize_minute,
    hour    => $optimize_hour,
    weekday => $optimize_day,
    require => [  Exec['mysql_set_rootpw'],
                  File['mysql_root_cnf'],
                  File['mysql_optimize_script'] ],
  }
}
