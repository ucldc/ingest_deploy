ansible-playbook -i hosts --extra-vars='name_suffix=-prod production=True' create_infrastructure_instances.yml &> create_prod_instances &
disown
