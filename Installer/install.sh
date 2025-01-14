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
if [ ! -d /apps ]; then
    mkdir /apps
fi
if [ ! -d /apps/bin ]; then
    mkdir /apps/bin
fi
if [ ! -d /apps/AprilTags ]; then
    mkdir /apps/AprilTags
fi

# clean out alll of the odd stuff that could be in the AprilTags dir
if ! [[ $preserve == "t" ]]; then
    rm -rf /apps/AprilTags/*
fi

# again, just like with the uninstall, it should properly do the /apps/bin stuff based on what is here, but whatever works!
if [ -f /apps/bin/AprilTags.sh ]; then
	rm /apps/bin/AprilTags.sh
fi
if [ -f /apps/bin/libAprilTags.sh ]; then
	rm /apps/bin/libAprilTags.sh
fi

# copy the service to the services, refresh, then enable it
cp AprilTagsPipeline.service /etc/systemd/system
sudo chmod 755 /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload
systemctl enable AprilTagsPipeline.service

# add path modification in /etc/profile.d/ if not already there
# why two? idk. it just apparently should have both?
if [ ! -f /etc/profile.d/AddAppsToPaf.sh ]; then
	cp AddAppsToPath.sh /etc/profile.d/AddAppsToPath.sh
fi

# now onto the AprilTags specific items
cp -R AprilTags/ /apps/
cp -R  bin/* /apps/bin/

echo "The AprilTags service has been installed and enabled. Run 'AprilTags.sh --update all' in the Cuda project root to sync it to be run."
echo "HINT: program not found error? run 'export PATH=\$PATH:/apps/bin' in your session"
echo "HINT: if sudo will not work, try sudo -i or use the sudo with the binary absolute path (which is required for some commands)"
# adding the commands in the AddAppstoPaf might help to fix that issue
