function worker_ips()
{
    if [ ${DATA_BRANCH} == 'production' ]; then
    	worker_ips=`~/code/ec2.py --refresh-cache | jq '.tag_Name_ingest_prod_worker'`
    else
    	worker_ips=`~/code/ec2.py --refresh-cache | jq '.tag_Name_ingest_stage_worker'`
    fi
    echo $worker_ips
}
