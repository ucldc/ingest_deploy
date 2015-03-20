ansible-playbook -i ~/code/ec2.py --extra-vars='name_env=ingest-prod name_suffix=-prod production=True' ~/code/ingest_deploy/ansible/provision_worker.yml

