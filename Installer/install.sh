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

# make sure the /opt/AprilTags dir is present
if [ ! -d /opt/AprilTags ]; then
    mkdir -p /opt/AprilTags
fi

# clean out all of the odd stuff that could be in the AprilTags dir
if ! [[ $preserve == "t" ]]; then
    rm -rf /opt/AprilTags/*
else
    rm -rf /opt/AprilTags/bin /opt/AprilTags/AprilTagsManager.sh /opt/AprilTags/args /opt/AprilTags/uninstall.sh
fi

# copy files into places
cp -R AprilTags/* /opt/AprilTags
cp -R bin/ /opt/AprilTags
cp uninstall.sh /opt/AprilTags

# Symlinks!!!
ln -s /opt/AprilTags/bin/AprilTags.sh /bin/AprilTags
ln -s /opt/AprilTags/bin/libAprilTags.sh /bin/libAprilTags
arch=$(uname -m)
if [[ -f "bin/camerascanner/scanner_${arch}" ]]; then
    ln -s /opt/AprilTags/bin/camerascanner/"scanner_${arch}" /bin/AprilTags_camerascanner
else
    if [[ $arch == "x86_64" ]]; then
    # x86 can run aarch64 binaries for some reason, so do that
    ln -s /opt/AprilTags/bin/camerascanner/scanner_aarch64 /bin/AprilTags_camerascanner
   fi
   # if not, do nothing!
fi

# copy the service to the services, refresh, then enable it
cp AprilTagsPipeline.service /etc/systemd/system
chmod 755 /etc/systemd/system/AprilTagsPipeline.service
systemctl daemon-reload
systemctl enable AprilTagsPipeline.service # not now, since files might not be there

echo "The AprilTags service has been installed and enabled. Run 'AprilTags --update' in the Cuda project root to sync it to be run."
echo "No hints! The code should work just fine if you run sudo on the binaries as needed."
# adding the commands in the AddAppstoPaf might help to fix that issue
