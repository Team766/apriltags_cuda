#! /bin/bash

# root check
if [ $EUID -ne 0 ]; then
	echo "please just run this with root, thx"
	exit 1
fi

if [[ $1 == "-p" ]] || [[ $1 == "--preserve" ]]; then
	preserve="t"
elif [ $# -eq 0 ]; then
	#ngl, do nothing, its just to stop it from having an error
	echo "HINT: reinstalling? run with -p or --preserve to preserve the currently present backend and web code"
else
	echo "unknown args"
	exit 2
fi

# make sure the directories are present
if [ ! -d /opt/AprilTags ]; then
    mkdir -p /opt
fi
if [ ! -d /bin/AprilTags ]; then
    mkdir /bin/AprilTags
fi

# clean out alll of the odd stuff that could be in the AprilTags dir
if ! [[ $preserve == "t" ]]; then
    rm -rf /opt/AprilTags/*
fi

# copy everything into /bin/AprilTags
cp -R AprilTags/ /bin/AprilTags/
cp -R bin/* /bin/AprilTags

# copy the service to the services, refresh, then enable it
cp AprilTagsPipeline.service /etc/systemd/system
chmod 755 /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload
systemctl enable AprilTagsPipeline.service # not now, since files might not be there

echo "The AprilTags service has been installed and enabled. Run 'AprilTags.sh --update' in the Cuda project root to sync it to be run."
echo "No hints! The code should work just fine if you run sudo on the binaries as needed."
# adding the commands in the AddAppstoPaf might help to fix that issue
