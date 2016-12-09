#!/bin/bash

# RUN with snsatnow

if [[ -n "$DEBUG" ]]; then 
  set -x
fi

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # http://stackoverflow.com/questions/59895
cd $DIR

usage(){
    echo "grab-solr-index.sh"
    exit 1
}


if [ $# -ne 0 ];
  then
    usage
fi

DATA_BRANCH=production
echo "DB $DATA_BRANCH"

. ~/.harvester-env

set +o nounset
. ~/python2/bin/activate
set -o nounset

dt=`date '+%Y%m%d_%H%M%S'`

stdbuf -i0 -o0 -e0 ansible-playbook \
    ~/bin/grab-solr-index-playbook.yml \
    --extra-vars="server_role=production" --limit="solr-production"
