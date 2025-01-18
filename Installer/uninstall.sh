#! /bin/bash

# root check
if [ $EUID -ne 0 ]; then
	echo "please just run this with root, thx"
	exit 1
fi

if [[ $1 == "all" ]]; then
	fullrm="t"
elif [ $# -eq 0 ]; then
	#ngl, do nothing, its just to stop it from having an error
	echo "HINT: if you want a full removal, then you can run it while specifying the 'all' parameter with this script."
else
	echo "unknown args"
	exit 2
fi

# stop the service then it dies, then remove it
systemctl disable AprilTagsPipeline.service
rm /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload

rm -rf /apps/AprilTags/

# for now, the stuff in bin is going to be manually specified, but later it can be read from the bin here
if [ -f /apps/bin/AprilTags.sh ]; then
	rm /apps/bin/AprilTags.sh
fi
if [ -f /apps/bin/libAprilTags.sh ]; then
	rm /apps/bin/libAprilTags.sh
fi

function isDirEmpty() {
	if [ -z "${ ls -A $1}" ]; then
		echo empty
		return 0 # empty
	else
		echo nempty
		return 1 # not empty
	fi
}

if [[ $fullrm == "t" ]]; then
	if [ -z "$( ls -A '/apps/bin/' )" ]; then
		rm -d /apps/bin
		rm /etc/profile.d/AddAppsToPath.sh
	fi

	if [ -z "$( ls -A '/apps/' )" ]; then
		rm -d /apps
	fi
	echo "full uninstall is as completed as it can be!"
fi

echo "The AprilTags service has been uninstalled from your system!"
