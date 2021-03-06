#!/usr/bin/bash

USER=snarl
GROUP=$USER
DBID=1
BACKUP_FILE=/var/db/snarl/backup_$DBID.tar.gz

case $2 in
    PRE-INSTALL)
	if grep "^$GROUP:" /etc/group > /dev/null 2>&1
	then
	    echo "Group already exists, skipping creation."
	else
	    echo Creating snarl group ...
	    groupadd $GROUP
	fi
	if id $USER > /dev/null 2>&1
	then
	    echo "User already exists, skipping creation."
	else
	    echo Creating snarl user ...
	    useradd -g $GROUP -d /var/db/snarl -s /bin/false $USER
	fi
    if [ ! -f $BACKUP_FILE -a -d /var/db/snarl/ring ]
    then
        echo "############################################################"
        echo "# This release introduces a update in the Database!        #"
        echo "# To ensure a a fallback option a backup file if the       #"
        echo "# database is created                                      #"
        echo "############################################################"
        echo $BACKUP_FILE
        tar cfz $BACKUP_FILE /var/db/snarl/{[0-9]*,ring}
    fi
	echo Creating directories ...
	mkdir -p /var/db/snarl/ring
	mkdir -p /var/db/snarl/users
	mkdir -p /var/db/snarl/groups
	chown -R snarl:snarl /var/db/snarl
	mkdir -p /var/log/snarl/sasl
	chown -R snarl:snarl /var/log/snarl
	;;
    POST-INSTALL)
	if svcs svc:/network/snarl:default > /dev/null 2>&1
	then
	    echo Service already existings ...
	else
	    echo Importing service ...
	    svccfg import /opt/local/snarl/share/snarl.xml
	fi

	echo Trying to guess configuration ...
	IP=`ifconfig net0 | grep inet | awk -e '{print $2}'`
	if [ ! -f /opt/local/snarl/etc/vm.args ]
	then
	    cp /opt/local/snarl/etc/vm.args.example /opt/local/snarl/etc/vm.args
	    sed --in-place -e "s/127.0.0.1/${IP}/g" /opt/local/snarl/etc/vm.args
	fi
	if [ ! -f /opt/local/snarl/etc/app.config ]
	then
	    cp /opt/local/snarl/etc/app.config.example /opt/local/snarl/etc/app.config
	    sed --in-place -e "s/127.0.0.1/${IP}/g" /opt/local/snarl/etc/app.config
	fi
	cp /opt/local/snarl/bin/snaadm /opt/local/sbin
	;;
esac
