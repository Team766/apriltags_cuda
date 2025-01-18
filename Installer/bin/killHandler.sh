#! /bin/bash

if [[ "$1" =~ ^-?[0-9]+$ ]]; then # regex to find int
    # assume its a PID that belongs to ws_server if running
    if ps -p $1 > /dev/null
    then
        killpid=$1
    fi
fi

# stop if unset
if [ -z ${killpid+x} ]; then exit 1; fi

# catch: kill -9
trap 'kill -9 ${killpid}' INT

kill -2 ${killpid}
