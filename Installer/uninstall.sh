#! /bin/bash

# root check
if [ $EUID -ne 0 ]; then
	echo "please just run this with root, thx"
	exit 1
fi

function unlnifthere() {
    if [ -h $1 ]; then
        unlink $1
    fi
}

# stop the service then it dies, then remove it
systemctl disable AprilTagsPipeline.service
rm /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload

rm -rf /opt/AprilTags

# rm the bin symlinks
unlnifthere /bin/AprilTags
unlnifthere /bin/libAprilTags
unlnifthere /bin/AprilTags_camerascanner

echo "The AprilTags service has been uninstalled from your system!"
