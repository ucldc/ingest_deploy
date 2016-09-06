function worker_ips()
{
    worker_ips=`~/code/ec2.py | jq '.tag_Name_ingest_stage_worker'`
    echo $worker_ips
}
