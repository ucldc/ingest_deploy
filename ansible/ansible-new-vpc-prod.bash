ansible-playbook -i hosts --extra-vars='name_suffix=-prod production=True' create_new_vpc.yml &> create_prod_env.out &
disown
