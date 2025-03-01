#! /bin/bash

# functions I need for AprilTags that could be used by the manager or the other script in bin

# get proc pid (0 notfound/error, else is the pid)
function getProcPID() {
    # NOTE: this returns the OLDEST PID
    paths=$(ps -aux | grep $1 | grep -v 'grep' | grep -v 'libAprilTags pid') #last section removes command syntax for this command
    # the quotes preserve linebreaks
    # rewriting the for loop, since its done in a subshell and causes issues when written normally
    while read line; do
        pid=$(echo $line | awk '{ printf $2}')
        re='^[0-9]+$'
        if [[ $pid =~ $re ]]; then
            echo $pid
            return
        fi
    done <<< "$(echo "$paths")"
    echo 0
}

echoerr() { echo "$@" 1>&2; } # bypass capture by var assigning because std::err

if [[ $1 == "pid" ]]; then
    getProcPID $2
elif [[ $1 == "camIDs" ]]; then
    if [[ -f /bin/AprilTags_camerascanner ]]; then
        ret=$(AprilTags_camerascanner)
    else
        ret=$(go run /opt/AprilTags/bin/camerascanner/scanner.go)
    fi
    
    if [[ "${ret,,}" == *"err"* ]] || [[ "${ret,,}" == *"fault"* ]]; then
    	# the majority of time that this control path gets reached will be because Go tries to run main, but then lacks some variables and errors out
    	echoerr "The Go code probably ran into an error. Look at the logs above to see it, otherwise make sure you have cameras plugged in."
    	exit 1
    elif ! [[ "${ret:0:1}" == "[" ]] || ! [[ "${ret: -1}" == "]" ]]; then
    	# There might be some novel way that this control path can be reached, for the most part, this will not get here
        echoerr "This is some novel error that I do not know how got here. Make sure you have cameras plugged in."
        exit 1
    fi
    # all good
    echo "${ret:1: -1}"
    exit 0
elif [[ $1 == "getCamLoc" ]]; then
    camlocfile="/opt/AprilTags/data/camlocations"
    camid=$2
    if ! [[ -f $camlocfile ]]; then
        echo "cam locations file not found."
        exit 1 # maybe stop using the same number
    fi
    # must have the file, assume that the file is correct
    set -e # just in case
    found=false
    cat $camlocfile | while read line || [ -n "$line" ] ; do
        lineparts=($line)
        if [[ "$2" == "${lineparts[0]}" ]] && [[ "$2" != "id" ]]; then
            # do note, this will happily pass "NOT-INSTALLED" as its return value, the manager will die when it gets this
            echo ${lineparts[1]}
            found=true
            # exit does nothing
        fi
    done
    if [[ found ]]; then
        exit 0
    fi
    echoerr "id not found"
    exit 1 # again, same code
elif [[ $1 == "killHandler" ]]; then
    if [[ "$2" =~ ^-?[0-9]+$ ]]; then # regex to find int
        # assume its a PID that belongs to ws_server if running
        if ps -p $2 > /dev/null
        then
            killpid=$2
        fi
    fi

    # stop if unset
    if [ -z ${killpid+x} ]; then exit 1; fi

    # catch: kill -9
    trap 'kill -9 ${killpid}' INT

    kill -2 ${killpid}
    
    while [ -d "/proc/$killpid" ]; do
        sleep 0.1 $ wait $!
    done
elif [[ $1 == "getRobot" ]]; then
    if [[ $2 == "ignoreNoRobot" ]]; then
        ignoreMissingRobotArg=true
    fi
    robotfile="/opt/AprilTags/data/robot.txt"
    if ! [[ -f $robotfile ]]; then
        echo "robot.txt file not found."
        exit 1 # maybe stop using the same number
    fi
    robot=$(cat $robotfile)
    # verify that the file is not empty and if it is return cam if issues or error
    if [[ ! -z ${robot+x} ]]; then
        echo $robot
        exit 0
    elif [[ ignoreMissingRobotArg ]]; then
        echo "cam"
        exit 0
    fi
    echoerr "id not found"
    exit 1 # again, same code
fi
