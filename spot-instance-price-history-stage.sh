#aws ec2 describe-spot-price-history --instance-types=m3.large --product-description "Linux/UNIX (Amazon VPC)" --availability-zone us-west-2b --max-items 10
my_dir="$(dirname "$0")"
aws ec2 describe-spot-price-history --instance-types=m3.large --product-description "Linux/UNIX (Amazon VPC)" --availability-zone us-west-2b --max-items 10 | jq '.SpotPriceHistory[].SpotPrice'
echo $(grep spot_bid ${my_dir}/ansible/group_vars/stage)
