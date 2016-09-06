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

worker_ips

 #1013  ~/code/ec2.py | jq '._meta.hostvars["10.60.16.8"]'
 #1014  ~/code/ec2.py | jq '._meta.hostvars["10.60.16.8"].ec2_id'
