function post_sns_message()
# args: post_sns_message(env_name, env_cname, subject, message)
#	subject: here doc subject (no double quotes please)
#	message: here doc message (no double quotes please)
{
	set -u
	subject="$1"
	message="$2"
	aws sns publish \
		--topic-arn "arn:aws:sns:us-west-2:563907706919:ucldc-harvesting" \
		--subject "${subject}" \
		--message "${message}"
}


