#! /bin/bash

if [ $# -ne 1 ]; then
    echo "only run with one argument"
    exit 1
fi

if [ ! -f '/opt/AprilTags/Backend/ws_server' ]; then
    echo "missing backend"
    exit 2
fi

function killIfRunning() {
    PID=`libAprilTags pid $1`
    if [ $PID -ne 0 ]; then
        kill -2 $PID
        return 1
    fi
    return 0
}

# set clocks to max frequency (jetson only)
jetson_clocks || true 1>&2 >> /dev/null

#open source for args
source /opt/AprilTags/args

if [[ $1 == "start" ]]; then
    # check for lock
    if [ -f "/opt/AprilTags/servicerunning" ]; then
        echo "service is already running"
        echo "HINT: if you think the service is not running, then run 'AprilTags --validate lockfile'"
        # now check if it is allowed to remove the lockfile..
        if [[ $autormlockfile == "true" ]]; then
        	# check for if the services are fine
        	status=$(AprilTags -V lockfile)
        	lockfilestatus=$(echo $status | awk -F ";" '{print $1}' | awk -F "=" '{print $2}')
        	if [[ $lockfilestatus == "false" ]]; then
        		# the lockfile is gone, and nothing is wrong
        		echo "removed old lockfile"
        	else
        		echo "the service is still running... exiting"
        		echo "Specific status: ${lockfilestatus}"
        		exit 4
        	fi
        else
        	# either unable to remove the lock or it is running already
        	exit 4
        fi
    fi

    touch /opt/AprilTags/servicerunning
    
    cams=`libAprilTags camIDs`
    if [[ $? -ne 0 ]]; then
    	echo "No cameras found or something. Try plugging some in, or else the cameras are not being seen."
    	exit 5
    fi
    
    cd /opt/AprilTags # seasocks depends on this
    
    robot=`libAprilTags getRobot ignoreNoRobot`
    if [[ $? -ne 0 ]]; then
    	echo "Finding the robot name errored out.. Try configuring it."
    	exit 6
    fi
    
    # iterate
    for cam in $cams; do
        # set items off of the output cam
        IFS=: read -r camID camIndex <<< "$cam"

        # get the offset file
        camLoc=$(libAprilTags getCamLoc $camID)
        if [[ $? -ne 0 ]]; then
            echo "FAILED TO FIND CAMERA OFFSET ${camID}, EXITING..."
            exit 6
        elif [[ $camLoc == "NOT-INSTALLED" ]]; then
            echo "INSTALLED CAMERA ${camID} MARKED \"NOT INSTALLED\", EXITING..."
            exit 7
        fi
        
        camFilePlace="/opt/AprilTags/data/camlocs/${robot}-${camLoc}-offset.json"
        if ! [[ -f $camFilePlace ]]; then
            echo "FAILED TO FIND CAMERA OFFSET FILE FOR CAM ${camID} with location ${camLoc} on robot ${robot} (file missing ${camFilePlace}"
            exit 6
        fi
        
        # ensure that the calibration file exists
        if ! [[ -f /opt/AprilTags/data/calibration/calibrationmatrix_${camID}.json ]]; then
            echo "FAILED TO FIND CAMERA CALIBRATION FILE ${camID}, EXITING..."
            exit 6
        fi
        
        # set camName
        if [[ ${camLoc} == "TEMPLATE" ]]; then
            camName="cam${camID}"
        else
            camName="${camLoc}"
        fi
        
        # set args
        args=`$backend` # this actually is magical because of the weird eval thing
        # https://stackoverflow.com/questions/5112663/bash-variable-reevaluation
        
        # abs path BECAUSE of the proc getting commands
        /opt/AprilTags/Backend/ws_server $args &
        echo $! >> /opt/AprilTags/servicerunning # add every pid to a new line
    done
    
    exit

elif [[ $1 == "stop" ]]; then
    if [[ -f /opt/AprilTags/servicerunning ]]; then
    	# read the file, kill if a pid is found inside
    	while read p; do
    	    if [[ "$p" =~ ^-?[0-9]+$ ]]; then # regex to find int
    	    	# assume its a PID that belongs to ws_server if running
    	    	if ps -p $p > /dev/null
    	    	then
    	    	    timeout -s INT 5s 'libAprilTags killHandler ${p}' &
    	        fi
    	    fi
    	done < /opt/AprilTags/servicerunning
    fi
    # and add the rest of it
    # this is broken, and I am too lazy to fix it
    #killIfRunning '/apps/AprilTags/Backend/ws_server'
    #while killIfRunning '/apps/AprilTags/Backend/ws_server'; do
    #	continue # just run the initial condition, a backup if the service orphaned something
    #done
    
    rm /opt/AprilTags/servicerunning
else
    echo "input ${1} not understood"
    exit 3
fi
