#!/bin/env bash
my_dir="$(dirname "$0")"

set -o errexit
set -o errtrace

# clone a new environment and point to the given new index in S3
if [ $# -ne 1 ]; then
    echo "clone-with-new-s3-index.sh <s3 path to new index>"
    exit 1
fi

source beanstalk_functions.sh

set -o nounset

new_index_path=$1

echo "ENV_NAME=${ENV_NAME}"
echo "NEW_ENV_NAME=${NEW_ENV_NAME}"

#blocks until status "OK"
eb clone ${ENV_NAME} -n ${NEW_ENV_NAME} --cname ${NEW_ENV_NAME} --timeout=20

update_index ${env_name} ${new_index_path}
check_api_url ${NEW_ENV_NAME}
