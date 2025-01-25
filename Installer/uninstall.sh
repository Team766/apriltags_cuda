#! /bin/bash

# root check
if [ $EUID -ne 0 ]; then
	echo "please just run this with root, thx"
	exit 1
fi

# stop the service then it dies, then remove it
systemctl disable AprilTagsPipeline.service
rm /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload

rm -rf /opt/AprilTags

# for now, the stuff in bin is going to be manually specified, but later it can be read from the bin here
if [ -d /bin/AprilTags ]; then
	rm -rf /bin/AprilTags
fi

echo "The AprilTags service has been uninstalled from your system!"
