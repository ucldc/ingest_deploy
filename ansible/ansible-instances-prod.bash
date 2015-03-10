ansible-playbook -i hosts --extra-vars='name_end=prod dev=False' create_infrastructure_instances.yml |tee create_prod_instances
#ansible-playbook -i hosts --extra-vars='name_end=prod dev=False' create_infrastructure_instances.yml &> create_prod_instances &
#disown
