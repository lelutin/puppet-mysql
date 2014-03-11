# debian way of calling plugins
class mysql::server::munin::debian {

  munin::plugin {
    [mysql_queries, mysql_slowqueries, mysql_bytes, mysql_threads]:
      config => "user root\nenv.mysqlopts --defaults-file=/etc/mysql/debian.cnf",
  }

  munin::plugin::deploy{
    'mysql_connections':
      source => 'mysql/munin/mysql_connections';
    'mysql_qcache':
      source => 'mysql/munin/mysql_qcache';
    'mysql_qcache_mem':
      source => 'mysql/munin/mysql_qcache_mem';
    'mysql_size_all':
      source => 'mysql/munin/mysql_size_all';
  }

  Munin::Plugin::Deploy[ [ 'mysql_connections', 'mysql_qcache', 'mysql_qcache_mem', 'mysql_size_all' ] ] {
    config  => "user root\nenv.mysqlopts --defaults-file=/etc/mysql/debian.cnf",
    require => Package['mysql'],
  }

}
