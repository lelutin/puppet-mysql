# A grant is either global or per-db. This can be distinguished by the syntax
# of the name:
#   user@host => global
#   user@host/db => per-db

require 'puppet/provider/package'

mysql_version = Facter.value(:mysql_version)
if mysql_version =~ /^5.0/
  MYSQL_USER_PRIVS = [ :select_priv, :insert_priv, :update_priv, :delete_priv,
    :create_priv, :drop_priv, :reload_priv, :shutdown_priv, :process_priv,
    :file_priv, :grant_priv, :references_priv, :index_priv, :alter_priv,
    :show_db_priv, :super_priv, :create_tmp_table_priv, :lock_tables_priv,
    :execute_priv, :repl_slave_priv, :repl_client_priv, :create_view_priv,
    :show_view_priv, :create_routine_priv, :alter_routine_priv,
    :create_user_priv
]
else
  MYSQL_USER_PRIVS = [ :select_priv, :insert_priv, :update_priv, :delete_priv,
    :create_priv, :drop_priv, :reload_priv, :shutdown_priv, :process_priv,
    :file_priv, :grant_priv, :references_priv, :index_priv, :alter_priv,
    :show_db_priv, :super_priv, :create_tmp_table_priv, :lock_tables_priv,
    :execute_priv, :repl_slave_priv, :repl_client_priv, :create_view_priv,
    :show_view_priv, :create_routine_priv, :alter_routine_priv,
    :create_user_priv, :trigger_priv
  ]
end

if mysql_version =~ /^5.1/ && mysql_version.split('.').last.to_i >= 6
  MYSQL_DB_PRIVS = [ :select_priv, :insert_priv, :update_priv, :delete_priv,
    :create_priv, :drop_priv, :grant_priv, :references_priv, :index_priv,
    :alter_priv, :create_tmp_table_priv, :lock_tables_priv, :create_view_priv,
    :show_view_priv, :create_routine_priv, :alter_routine_priv, :execute_priv,
    :event_priv, :trigger_priv
  ]
else
  MYSQL_DB_PRIVS = [ :select_priv, :insert_priv, :update_priv, :delete_priv,
    :create_priv, :drop_priv, :grant_priv, :references_priv, :index_priv,
    :alter_priv, :create_tmp_table_priv, :lock_tables_priv, :create_view_priv,
    :show_view_priv, :create_routine_priv, :alter_routine_priv, :execute_priv,
  ]
end

MYSQL_TABLE_PRIVS = [ :select, :insert, :update, :delete, :create, :drop, 
		      :references, :index, :alter
]

MYSQL_COLUMN_PRIVS = [ :select_priv, :insert_priv, :update_priv, :references_priv ]

Puppet::Type.type(:mysql_grant).provide(:mysql) do

  desc "Uses mysql as database."

  commands :mysql => '/usr/bin/mysql'
  commands :mysqladmin => '/usr/bin/mysqladmin'

  # Optional defaults file
  def self.defaults_file
    if File.file?("#{Facter.value(:root_home)}/.my.cnf")
      "--defaults-file=#{Facter.value(:root_home)}/.my.cnf"
    else
      nil 
    end 
  end 
  def defaults_file
    self.class.defaults_file
  end 

  def mysql_flush 
    mysqladmin(defaults_file, "flush-privileges")
  end

  # this parses the
  def split_name(string)
    matches = /^([^@]*)@([^\/]*)(\/([^\/]*))?(\/([^\/]*))?$/.match(string).captures.compact

    case matches.length 
      when 2
        {
          :type => :user,
          :user => matches[0],
          :host => matches[1]
        }
      when 4
        {
          :type => :db,
          :user => matches[0],
          :host => matches[1],
          :db => matches[3]
        }
      when 6
        {
          :type => :tables_priv,
          :user => matches[0],
          :host => matches[1],
          :db => matches[3],
          :table_name => matches[5]
        }
      when 8
        {
          :type => :table,
          :user => matches[0],
          :host => matches[1],
          :db => matches[3],
          :table => matches[5],
          :column => matches[7]
        }
    end
  end

  def create_row
    unless @resource.should(:privileges).empty?
      name = split_name(@resource[:name])
      case name[:type]
      when :user
        mysql(defaults_file, "mysql", "-e", "INSERT INTO user (host, user) VALUES ('%s', '%s')" % [
          name[:host], name[:user],
        ])
      when :db
        mysql(defaults_file, "mysql", "-e", "INSERT INTO db (host, user, db) VALUES ('%s', '%s', '%s')" % [
          name[:host], name[:user], name[:db],
        ])
      when :column
        mysql(defaults_file, "mysql", "-e", "INSERT INTO columns_priv (host, user, db, table, column_name) VALUES ('%s', '%s', '%s', '%s', '%s')" % [
          name[:host], name[:user], name[:db], name[:table], name[:column],
        ])
      end
      mysql_flush
    end
  end

  def destroy
    mysql(defaults_file, "mysql", "-e", "REVOKE ALL ON '%s'.* FROM '%s@%s'" % [ @resource[:privileges], @resource[:database], @resource[:name], @resource[:host] ])
  end
  
  def row_exists?
    name = split_name(@resource[:name])
    fields = [:user, :host]
    if name[:type] == :db
      fields << :db
    end
    if name[:type] == :column
      fields << :column
    end
    not mysql(defaults_file, "mysql", "-NBe", 'SELECT "1" FROM %s WHERE %s' % [ name[:type], fields.map do |f| "%s = '%s'" % [f, name[f]] end.join(' AND ')]).empty?
  end

  def all_privs_set?
    all_privs = case split_name(@resource[:name])[:type]
      when :user
        MYSQL_USER_PRIVS
      when :db
        MYSQL_DB_PRIVS
      when :tables_priv
        MYSQL_TABLE_PRIVS
      when :column
        MYSQL_COLUMN_PRIVS
    end
    all_privs = all_privs.collect do |p| p.to_s end.sort.join("|")
    privs = privileges.collect do |p| p.to_s end.sort.join("|")

    all_privs == privs
  end

  def privileges 
    name = split_name(@resource[:name])
    privs = ""

    case name[:type]
    when :user
      privs = mysql(defaults_file, "mysql", "-Be", 'select * from user where user="%s" and host="%s"' % [ name[:user], name[:host] ])
    when :db
      privs = mysql(defaults_file, "mysql", "-Be", 'select * from db where user="%s" and host="%s" and db="%s"' % [ name[:user], name[:host], name[:db] ])
    when :tables_priv
      privs = mysql(defaults_file, "mysql", "-NBe", 'select Table_priv from tables_priv where User="%s" and Host="%s" and Db="%s" and Table_name="%s"' % [ name[:user], name[:host], name[:db], name[:table_name] ])
      privs = privs.chomp.downcase
      return privs
    when :columns
      privs = mysql(defaults_file, "mysql", "-Be", 'select * from columns_priv where User="%s" and Host="%s" and Db="%s" and Table_name="%s" and Column_name="%s"' % [ name[:user], name[:host], name[:db], name[:table], name[:column] ])
    end

    if privs.match(/^$/) 
      privs = [] # no result, no privs
    else
      case name[:type]
      when :user, :db
      # returns a line with field names and a line with values, each tab-separated
        privs = privs.split(/\n/).map! do |l| l.chomp.split(/\t/) end
        # transpose the lines, so we have key/value pairs
        privs = privs[0].zip(privs[1])
        privs = privs.select do |p| (/_priv$/) and p[1] == 'Y' end
        privs.collect{|p| p[0].downcase.intern }
      end
    end
  end

  def privileges=(privs) 
    name = split_name(@resource[:name])
    # don't need to create a row for tables_priv and columns_priv
    if name[:type] == :user || name[:type] == :db
      unless row_exists?
        create_row
      end
    end

    # puts "Setting privs: ", privs.join(", ")
    name = split_name(@resource[:name])
    stmt = ''
    where = ''
    all_privs = []
    case name[:type]
    when :user
      stmt = 'update user set '
      where = ' where user="%s" and host="%s"' % [ name[:user], name[:host] ]
      all_privs = MYSQL_USER_PRIVS
    when :db
      stmt = 'update db set '
      where = ' where user="%s" and host="%s"' % [ name[:user], name[:host] ]
      all_privs = MYSQL_DB_PRIVS
    when :tables_priv
      currently_set = privileges
      currently_set = currently_set.scan(/\w+/)
      privs.map! {|i| i.to_s.downcase}
      revoke = currently_set - privs

      if !revoke.empty?
         #puts "Revoking table privs: ", revoke
         mysql(defaults_file, "mysql", "-e", "REVOKE %s ON %s.%s FROM '%s'@'%s'" % [ revoke.join(", "), name[:db], name[:table_name], name[:user], name[:host] ])
      end

      set = privs - currently_set
      stmt = 'GRANT '
      where = ' ON %s.%s TO "%s"@"%s"' % [ name[:db], name[:table_name], name[:user], name[:host] ]
      all_privs = MYSQL_TABLE_PRIVS    
    when :column
      stmt = 'update columns_priv set '
      where = ' where user="%s" and host="%s" and Db="%s" and Table_name="%s"' % [ name[:user], name[:host], name[:db], name[:table_name] ]
      all_privs = MYSQL_COLUMN_PRIVS    
    end

    if privs[0] == :all 
      privs = all_privs
    end
  
    #puts "stmt:", stmt
    case name[:type]
    when :user
      set = all_privs.collect do |p| "%s = '%s'" % [p, privs.include?(p) ? 'Y' : 'N'] end.join(', ')
    when :db
      set = all_privs.collect do |p| "%s = '%s'" % [p, privs.include?(p) ? 'Y' : 'N'] end.join(', ')
    when :tables_priv
      set = set.join(', ')
    end

    #puts "set:", set
    stmt = stmt << set << where
    #puts "stmt:", stmt

    if !set.empty?
      mysql(defaults_file, "mysql", "-Be", stmt)
      mysql_flush
    end
  end
end

