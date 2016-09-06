#!/bin/bash

if [[ -n "$DEBUG" ]]; then
  set -x
fi

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # http://stackoverflow.com/questions/59895

source ${DIR}/info_functions.sh

if [ "$#" != 1 ]; then
    echo "get_log_events_for_akara.sh <worker ip>"
    exit 11
fi

worker_ip=$1
jq_search="'._meta.hostvars[\"${worker_ip}\"].ec2_id'"
jq_search="._meta.hostvars[\"${worker_ip}\"].ec2_id"
instance_id=$(~/code/ec2.py | jq ${jq_search}| tr --delete '"' )
log_stream_name=ingest-stage-${instance_id}-${worker_ip}
echo $log_stream_name
aws  logs get-log-events --log-group-name "/var/local/akara" --log-stream-name  ${log_stream_name}
echo "LOG STREAM NAME=${log_stream_name}"
