# $config needs to be a hash of key => value pairs.
#
# values in config are output as key = value, except when the value is empty;
# then just key is output. if you need to output an empty value in the form
# key = value, then you can specify empty quotes as the value (see example).
#
# mysql::conf { 'test':
#   ensure  => present,
#   section => 'mysqld',
#   config  => {
#     table_cache => '15000',
#     skip_slave  => '',
#     something   => '""',
#   }
# }
#
# This will generate the following contents:
# [mysqld]
# skip_slave
# something = ""
# table_cache = 15000
#
define mysql::conf (
  $section,
  $config,
  $ensure = present
) {

  include mysql::server::base

  file { "/etc/mysql/conf.d/${name}.cnf":
    ensure  => $ensure,
    content => template('mysql/conf.erb'),
    notify  => Service['mysql'],
  }

}
