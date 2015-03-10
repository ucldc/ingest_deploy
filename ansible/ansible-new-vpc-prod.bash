ansible-playbook -i hosts --extra-vars='name_end=prod production=True' create_new_vpc.yml &> create_prod_env.out &
disown
