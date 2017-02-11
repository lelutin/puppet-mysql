#!/bin/sh

test -f /root/.my.cnf || exit 1

must_have ()
{
    # Here, using "which" would not be appropriate since it also depends on
    # PATH being set correctly. The type builtin command is unaffected by the
    # environment.
    type $1 >/dev/null
    if [ $? -ne 0 ]; then
        echo "Command '$1' not found, did you correctly set PATH ? Its current value is: $PATH" >&2
        exit 1
    fi
}

# Since this script is doing something rather unsafe with the database, we want
# to be really careful to have all the necessary tools before doing anything so
# that we don't end up in an inconsistent state.
must_have sleep
must_have mysql
must_have killall
must_have ls
must_have chown

rootpw=$(grep password /root/.my.cnf | sed -e 's/^[^=]*= *\(.*\) */\1/')

/usr/bin/mysqladmin --defaults-file=/root/.my.cnf status > /dev/null && echo "Nothing to do as the password already works" && exit 0

if [ -x /etc/init.d/mysql ]; then
    /etc/init.d/mysql stop
elif [ -e /lib/systemd/system/mariadb.service ]; then
    systemctl stop mariadb
else
    exit 1
fi

/usr/sbin/mysqld --skip-grant-tables --user=root --datadir=/var/lib/mysql --log-bin=/var/lib/mysql/mysql-bin &
sleep 5
mysql -u root mysql <<EOF
UPDATE mysql.user SET Password=PASSWORD('$rootpw') WHERE User='root' AND Host='localhost';
DELETE FROM mysql.user WHERE (User='root' AND Host!='localhost') OR USER='';
FLUSH PRIVILEGES;
EOF
killall mysqld
sleep 15
# chown to be on the safe side
ls -al /var/lib/mysql/mysql-bin.* &> /dev/null
[ $? == 0 ] && chown mysql.mysql /var/lib/mysql/mysql-bin.*
chown -R mysql.mysql /var/lib/mysql/data/

if [ -x /etc/init.d/mysql ]; then
    /etc/init.d/mysql start
elif [ -e /lib/systemd/system/mariadb.service ]; then
    systemctl start mariadb
else
    exit 1
fi

