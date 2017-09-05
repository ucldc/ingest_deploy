#!/bin/bash

# Description: run stop-rqworker on shutdown
# chkconfig: 3 99 01

lockfile=/var/lock/subsys/rqworker-stop

case "$1" in
        start)
          touch ${lockfile}
          ;;
        stop)
          /usr/local/bin/stop-rqworker.sh
          rm ${lockfile}
          ;;
esac
