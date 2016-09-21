#!/bin/env bash
my_dir="$(dirname "$0")"

set -o errexit
set -o errtrace

source "${my_dir}/beanstalk_functions.sh"

# update an existing environment and point to the given new index in S3
if [ $# -ne 2 ]; then
    echo "$0 <env name> <s3 path to new index>"
    exit 1
fi

set -o nounset

env_name=$1
new_index_path=$2

update_index "${env_name} ${new_index_path}"
check_api_url "${env_name}"
