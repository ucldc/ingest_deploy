set -e
set -u

sudo yum update
sudo yum install gcc -y
sudo yum install make -y
sudo yum install git -y
sudo yum install python-pip -y
sudo pip install ansible
mkdir ~/code
pushd ~/code/
git clone https://github.com/mredar/ingest_deploy.git
