# debian ruby client
class mysql::client::ruby::debian {
  if $operatingsystemmajversion >= 7 {
    $package = 'ruby-mysql'
  } else {
    $package = 'libmysql-ruby'
  }
  ensure_packages([ $package ])
}
