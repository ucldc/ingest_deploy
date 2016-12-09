trap "echo ========killed========" SIGINT SIGTERM
# TODO: make this post to SNS?
#trap "echo ========exited========" EXIT

my_dir="$(dirname "$0")"
source "${my_dir}/post_sns_message.sh"

function cname_for_env()
{
    set -u
    env_name=$1
    #need to get the url for the ENVIRONMENT, not necessarily the name of env
    env_cname=$(aws elasticbeanstalk describe-environments --environment-names="${env_name}" | jq '.Environments[0].CNAME')
    env_cname=${env_cname%\"} #remove trailing " mark
    env_cname=${env_cname#\"} #remove initial " mark
    echo "${env_cname}"
}

function check_api_url()
{
    set -u
    env_name=$1
    #need to get the url for the ENVIRONMENT, not necessarily the name of env
    env_cname=$(cname_for_env "${env_name}")
    url_api=https://${env_cname}/solr/query
    # check the search url, should be working
    set +o errexit
    echo -e "CHECK API URL: \e[36m ${url_api} \e[0m"
    curl --insecure --fail --header "X-Authentication-Token: ${SOLR_API_KEY}" "${url_api}" > /dev/null
    last_exit=$?
    if [ $last_exit -ne 0 ]; then
        echo
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo -e "\033[1;31m !!!!!!!!!! API ${env_name} DOWN!!!!!! \033[0m"
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo
        echo -e "\033[1;31m Check ${url_api} before swapping \033[0m"
        echo -e "\033[1;31m wget --no-check-certificate --header \"X-Authentication-Token: <api_key>\"  ${url_api} before swapping \033[0m"
    else
		numFound=$(curl --insecure --fail --header "X-Authentication-Token: ${SOLR_API_KEY}" "${url_api}" | jq '.response.numFound')
        echo -e "\033[94m OK - ${env_name} API - \033[35m${numFound} items\033[0m"
    fi
}

function s3_file_exists()
{
    # check that the s3_index_path exists.
    set -u
    s3_index_path=$1
    #with errexit set, it exits when this fails
    exitcode=0
    aws s3 ls "${s3_index_path}" > /dev/null || exitcode=$?
    if [ ${exitcode} -ne 0 ]; then
		subject="Update Beanstalk index for ${env_name} failed"
		message="S3 index file does not exist: ${s3_index_path}"
		echo -e "\033[1;31m ${message}\033[0m"
        exit 11
    else
		# aws s3 ls works on partial paths, need to check that result is
		# the same as the passed in path
		# this input:
		# s3://solr.ucldc/indexes/production/2016/09/solr-index.2016-09-21-22_26_55
		# passes above and returns the name of tar.bz2 file there

		parent_path=${s3_index_path%/*}
		resp=$(aws s3 ls "${s3_index_path}") 
		fname=''
		for y in $resp
		do
			fname=$y
		done
		built_path="${parent_path}/${fname}"
		if [ ${s3_index_path} != ${built_path} ]; then
			subject="Update Beanstalk index for ${env_name} failed"
			message="THIS DOES NOT SEEM VALID: ${s3_index_path}"
			echo -e "\033[1;31m ${message}\033[0m"
			exit
		fi
        echo -e "\033[1;36m S3 index file exists, proceeding: ${s3_index_path} \033[0m"
    fi
}

function poll_until_ok()
{
    set -u
    env_name=$1
    status=bogus
    until [ "$status" == "\"Ok\"" ]; do
       sleep 60
	   status=$(aws elasticbeanstalk describe-environment-health --environment-name "${env_name}" --attribute-names HealthStatus | jq '.HealthStatus')
       echo "STATUS:$status"
    done
}

function update_index()
{
# Update the index running on the given environment with the new index S3 sub-path
    set -u
    env_name=$1
    s3_index_path=$2

    echo "env_name=${env_name}"
    # check that this env is NOT pointed at the production index
    env_cname=$(cname_for_env "${env_name}")
    if [[ ${env_cname} == ERROR* ]]; then
		subject="Update Beanstalk index for ${env_name} failed"
		message="CNAME is in use: ${env_cname}"
		echo -e "\033[1;31m ${message}\033[0m"
		post_sns_message "${subject}" "${message}"
        exit 9
    fi
    if [ "$env_cname" == "ucldc-solr.us-west-2.elasticbeanstalk.com" ]; then
        echo
        echo -e "\033[38;5;216m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo -e "\033[1;31m !!!!!!!!!! MASTER ENV ${env_name} !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! URL ENV ${env_cname} !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! BRINGING THIS DOWN WILL BREAK CALISPHERE !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! EXITING !!!!!! \033[0m"
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo
		subject="Update Beanstalk index for ${env_name} failed"
		message="THIS ENVIRONMENT \"${env_name}\" is production server.
THE CNAME ucldc-solr.us-west-2.elasticbeanstalk.com is the URL for the Calisphere index and updating this environment will cause an outage on Calisphere"
		post_sns_message "${subject}" "${message}"
        exit 111
    fi

    s3_file_exists "${s3_index_path}"
    # the eb version blocks until this is complete
    # but not working right, so added poll below
    resp_setenv=$(eb setenv -e "${env_name}" S3_INDEX_PATH="${s3_index_path}")
    # if fails, resp starts with ERROR
    if [[ ${resp_setenv} == ERROR* ]]; then
		subject="Update Beanstalk index for ${env_name} failed"
		message="Failed to setenv : ${resp_setenv}"
		echo -e "\033[1;31m ${message}\033[0m"
        exit 9
    fi
    poll_until_ok "${env_name}"

    # non-blocking
    # aws elasticbeanstalk update-environment --application-name ucldc-solr --environment-name ${env_name} --option-settings Namespace=aws:elasticbeanstalk:application:environment,OptionName=S3_INDEX_PATH,Value=$i{ndex_path}

    # non-blocking
    aws elasticbeanstalk rebuild-environment --environment-name "${env_name}"
    
    poll_until_ok "${env_name}"
	subject="Updated index : ${env_name}"
	message="Solr index for ${env_name} at ${env_cname} updated."
	post_sns_message "${subject}" "${message}"
}
