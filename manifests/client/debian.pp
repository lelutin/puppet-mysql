# debian client name
class mysql::client::debian inherits mysql::client::base {
  if $::operatingsystemmajrelease >= 9 {
    Package[mysql]{
      name => 'mariadb-client'
    }
  } else {
    Package['mysql'] {
      name => 'mysql-client',
    }
  }
}
