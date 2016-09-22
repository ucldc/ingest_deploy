#!/bin/env bash
my_dir="$(dirname "$0")"

set -o errexit
set -o errtrace

# clone a new environment and point to the given new index in S3
if [ $# -ne 3 ]; then
    echo "clone-with-new-s3-index.sh <old env> <new env> <s3 path to new index>"
    exit 1
fi

source "${my_dir}/beanstalk_functions.sh"

set -o nounset

old_env=$1
new_env=$2
new_index_path=$3

echo "old environment=${old_env}"
echo "new environment=${new_env}"

env_cname=$(cname_for_env "${new_env}")
if [[ ${env_cname} == ERROR* ]]; then
    echo -e "\033[1;31m CNAME is in use: ${env_cname}\033[0m"
    exit 9
fi
#blocks until status "OK"
eb clone "${old_env}" -n "${new_env}" --cname "${new_env}" --timeout=20

update_index "${new_env}" "${new_index_path}"
check_api_url "${new_env}"
