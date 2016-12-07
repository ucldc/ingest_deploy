function worker_ips()
{
	~/code/ec2.py --refresh-cache | \
		jq ".tag_Name_ingest_${DATA_BRANCH}_worker"
}
