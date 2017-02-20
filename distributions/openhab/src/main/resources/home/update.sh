#!/bin/bash
# An error exit function

function error_exit
{
	echo "$1" 1>&2
	exit 1
}

TIMESTAMP='date +%Y%m%d_%H%M%S';
# base installation path of openHAB2
BASEPATH='/opt/openhab2';
BACKUPPATH='/opt/backup/backup-oh2-';
# please set variable RELEASE to the current release
RELEASE='2.1.0';

# stop openhab2 service
echo "############################################"
echo "Stopping openHAB2 service..."
echo "############################################"
echo ""
if [ -x /bin/systemctl ] ; then
	/bin/systemctl stop openhab2.service
elif [ -x "/etc/init.d/openhab2" ]; then
	if [ -x "`which invoke-rc.d 2>/dev/null`" ]; then
		invoke-rc.d openhab2 stop || true
	else
		/etc/init.d/openhab2 stop || true
	fi
fi
if [ $? -ne 0 ]; then
	echo "############################################"
	error_exit "Error while stopping the service."
else
	echo "############################################"
	echo "Service stopped."
	echo "############################################"
	echo ""
fi

# backup current installation
if cd $BASEPATH; then
	if cd $BACKUPPATH; then
		echo "############################################"
		echo "Moving current installation to Backup Folder: "$BACKUPPATH$TIMESTAMP
		echo "############################################"
		echo ""
    # get current acl from openhab folder and save it to file
		sudo getfacl -R $BASEPATH > /tmp/oh2-perm-$TIMESTAMP.txt
		sudo mv $BASEPATH $BACKUPPATH$TIMESTAMP
		sudo mv /tmp/oh2-perm-$TIMESTAMP.txt $BACKUPPATH$TIMESTAMP/oh2-perm-$TIMESTAMP.txt
	else
		echo "############################################"
		echo "Backup Folder does not exist. Creating..."
		echo "############################################"
		echo ""
		sudo mkdir $BACKUPPATH
		echo "############################################"
		echo "Moving current installation to Backup Folder: "$BACKUPPATH$TIMESTAMP
		echo "############################################"
		echo ""
		sudo getfacl -R $BASEPATH > /tmp/oh2-perm-$TIMESTAMP.txt
		sudo mv $BASEPATH $BACKUPPATH$TIMESTAMP
		sudo mv /tmp/oh2-perm-$TIMESTAMP.txt $BACKUPPATH$TIMESTAMP/oh2-perm-$TIMESTAMP.txt
	fi
	else
		echo "############################################"
		error_exit "Error: openHAB2 folder not found."
fi

# download new version
echo "############################################"
echo "Trying to download current release..."
echo "############################################"
echo ""
if cd /tmp; then
	cd /tmp
	if [ -f "/tmp/openhab-$RELEASE-SNAPSHOT.zip" ]; then
		echo "############################################"
		echo "Allready downloaded - skipping download."
		echo "############################################"
		echo ""
		echo "############################################"
		echo "Extracting current Snapshot of openHAB2..."
		echo "############################################"
		echo ""
		sudo unzip openhab-$RELEASE-SNAPSHOT.zip -d $BASEPATH
		if [ $? -ne 0 ]; then
			echo "############################################"
			error_exit "Error while extracting zipfile."
		else
			echo "############################################"
			echo "unzip complete."
			echo "############################################"
			echo ""
		fi
	else
		echo "############################################"
		echo "Downloading current Snapshot of openHAB2..."
		echo "############################################"
		echo ""
		wget https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$RELEASE-SNAPSHOT.zip
		if [ $? -ne 0 ]; then
			echo "############################################"
			error_exit "Error while downloading..."
		else
			echo "############################################"
			echo "download complete."
			echo "############################################"
			echo ""
		fi
		echo "Extracting current Snapshot of openHAB2..."
		sudo unzip openhab-$RELEASE-SNAPSHOT.zip -d $BASEPATH
		if [ $? -ne 0 ]; then
			echo "############################################"
			error_exit "Error while extracting zipfile."
		else
			echo "############################################"
			echo "unzip complete."
			echo "############################################"
			echo ""
		fi
		echo "############################################"
		echo "deleting openhab-$RELEASE-SNAPSHOT.zip"
		echo "############################################"
		echo ""
		rm openhab-$RELEASE-SNAPSHOT.zip
	fi
else
	echo "############################################"
	echo "TMP Folder does not exist. Creating..."
	echo "############################################"
	echo ""
	sudo mkdir /tmp
	cd tmp
	echo "############################################"
	echo "Downloading current Snapshot of openHAB2..."
	echo "############################################"
	echo ""
	wget https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$RELEASE-SNAPSHOT.zip
	if [ $? -ne 0 ]; then
		echo "############################################"
		error_exit "Error while downloading..."
	else
		echo "############################################"
		echo "download complete."
		echo "############################################"
		echo ""
	fi
	echo "Extracting current Snapshot of openHAB2..."
	sudo unzip openhab-$RELEASE-SNAPSHOT.zip -d $BASEPATH
	if [ $? -ne 0 ]; then
		echo "############################################"
		error_exit "Error while extracting zipfile."
	else
		echo "############################################"
		echo "unzip complete."
		echo "############################################"
		echo ""
	fi
	echo "############################################"
	echo "deleting openhab-$RELEASE-SNAPSHOT.zip"
	echo "############################################"
	echo ""
	rm openhab-$RELEASE-SNAPSHOT.zip
fi

# restore configuration and userdata
echo "############################################"
echo "Restoring old configuration and userdata..."
echo "############################################"
echo ""
sudo cp -arv $BACKUPPATH$TIMESTAMP/conf $BASEPATH
sudo rsync -av --progress $BACKUPPATH$TIMESTAMP/userdata $BASEPATH --exclude={cache,tmp,etc,update.sh}

# fix permissions
cd $BASEPATH
setfacl --restore=$BACKUPPATH$TIMESTAMP/oh2-perm-$TIMESTAMP.txt

# restart openhab instance
if [ -x /bin/systemctl ] ; then
	/bin/systemctl start openhab2.service
elif [ -x "/etc/init.d/openhab2" ]; then
	if [ -x "`which invoke-rc.d 2>/dev/null`" ]; then
		invoke-rc.d openhab2 start || true
	else
		/etc/init.d/openhab2 start || true
	fi
fi
if [ $? -ne 0 ]; then
	echo "############################################"
	error_exit "Error while starting the service."
	echo "############################################"
	echo ""
else
	echo "############################################"
	echo "Service started."
	echo "############################################"
	echo ""
fi
echo "############################################"
echo "Upgrade complete"
echo "############################################"
