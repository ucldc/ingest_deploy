ansible-playbook -i ~/code/ec2.py --extra-vars='name_env=ingest-production name_suffix=-production production=True' ~/code/ingest_deploy/ansible/provision_worker.yml

