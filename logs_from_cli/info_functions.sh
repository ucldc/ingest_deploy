function worker_ips()
{
	~/code/ec2.py --refresh-cache | \
		jq ".tag_Name_ingest_${DATA_BRANCH}_worker"
}

function worker_info()
{
	~/code/ec2.py --refresh-cache | \
		jq "._meta.hostvars as \$hostvars | .tag_Name_ingest_${DATA_BRANCH}_worker[] |\$hostvars[.] | [.ec2_private_ip_address, .ec2_id, .ec2_state, .ec2_instance_type, .ec2_instanceLifecycle]"
}
