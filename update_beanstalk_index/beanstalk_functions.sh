function cname_for_env()
{
    set -u
    env_name=$1
    #need to get the url for the ENVIRONMENT, not necessarily the name of env
    env_cname=`aws elasticbeanstalk describe-environments --environment-names=${env_name} | jq '.Environments[0].CNAME'` 
    env_cname=${env_cname%\"} #remove trailing " mark
    env_cname=${env_cname#\"} #remove initial " mark
    echo $env_cname
}

function check_api_url()
{
    set -u
    env_name=$1
    #need to get the url for the ENVIRONMENT, not necessarily the name of env
    env_cname=$(cname_for_env ${env_name})
    url_api=https://${env_cname}/solr/query
    # check the search url, should be working
    set +o errexit
    echo "CHECK API URL: ${url_api}"
    curl --insecure --fail --header "X-Authentication-Token: ${API_KEY}" ${url_api} > /dev/null
    #wget --no-check-certificate --header "X-Authentication-Token: ${API_KEY}" -q ${url_api}
    last_exit=$?
    if [ $last_exit -ne 0 ]; then
        echo
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo -e "\033[1;31m !!!!!!!!!! API ${env_name} DOWN!!!!!! \033[0m"
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo
        echo -e "\033[1;31m Check ${url_api} before swapping \033[0m"
        echo -e "\033[1;31m wget --no-check-certificate --header \"X-Authentication-Token: <api_key>  ${url_api} before swapping \033[0m"
    else
        echo -e "\033[94m OK - ${env_name} API\033[0m"
    fi
}

function poll_until_ok()
{
    set -u
    env_name=$1
    status=bogus
    until [ "$status" == "\"Ok\"" ]; do
       sleep 60
       status=`aws elasticbeanstalk describe-environment-health --environment-name ${env_name} --attribute-names HealthStatus | jq '.HealthStatus'`
       echo "REBUILD STATUS:$status"
    done
}

function update_index()
{
# Update the index running on the given environment with the new index S3 sub-path
    set -u
    env_name=$1
    index_path=$2

    echo "env_name=${env_name}"
    #check that this env is NOT pointed at the prodcution index
    env_cname=$(cname_for_env ${env_name})
    if [ "$env_cname" == "ucldc-solr.us-west-2.elasticbeanstalk.com" ]; then
        echo
        echo -e "\033[38;5;216m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo -e "\033[1;31m !!!!!!!!!! MASTER ENV ${env_name} !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! URL ENV ${env_cname} !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! BRINGING THIS DOWN WILL BREAK CALISPHERE !!!!!! \033[0m"
        echo -e "\033[1;31m !!!!!!!!!! EXITING !!!!!! \033[0m"
        echo -e "\033[1;31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\033[0m"
        echo
        exit 111
    fi

    # the eb version blocks until this is complete
    eb setenv -e ${env_name} INDEX_PATH=${index_path}
    # non-blocking
    # aws elasticbeanstalk update-environment --application-name ucldc-solr --environment-name ${env_name} --option-settings Namespace=aws:elasticbeanstalk:application:environment,OptionName=INDEX_PATH,Value=$i{ndex_path}

    # non-blocking
    aws elasticbeanstalk rebuild-environment --environment-name ${env_name}
    
    poll_until_ok ${env_name}
}
