function worker_ips()
{
    worker_ips=`~/code/ec2.py --refresh-cache | jq '.tag_Name_ingest_stage_worker'`
    echo $worker_ips
}
