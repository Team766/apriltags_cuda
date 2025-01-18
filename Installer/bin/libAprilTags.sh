#! /bin/bash

# functions I need for AprilTags that could be used by the manager or the other script in bin

# get proc pid (0 notfound/error, else is the pid)
function getProcPID() {
    # NOTE: this returns the OLDEST PID
    paths=$(ps -aux | grep $1 | grep -v 'grep' | grep -v 'libAprilTags.sh pid') #last section removes command syntax for this command
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
    cd "${0%/*}"/camerascanner
    # run the go file in the most efficent way possible
    arch=$(uname -m)
    if [[ -f "scanner_${arch}" ]]; then
        ret=$("./scanner_${arch}")
    else
    	if [[ $arch == "x86_64" ]]; then
    	    # x86 can run aarch64 binaries for some reason, so do that
    	    ret=$("./scanner_aarch64")
    	    
    	else
            echoerr "running go file directly"
            ret=$(go run main)
        fi
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
    camlocfile="/apps/AprilTags/data/cameralocations"
    camid=$2
    if ! [[ -f camlocfile ]]; then
        echo "cam locations file not found."
        exit 1 # maybe stop using the same number
    fi
    # must have the file, assume that the file is correct
    set -e # just in case
    locfile=$(tail -n +1 camlocfile)
    for line in locfile; do
        if [[ "$2" == "${line[0]}" ]]; then
            echo line[1]
            exit 0
        fi
    done
    echo "id not found"
    exit 1 # again, same code
fi
