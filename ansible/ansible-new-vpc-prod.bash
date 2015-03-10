ansible-playbook -i hosts --extra-vars='name_end=prod dev=False' create_new_vpc.yml &> create_prod_env.out &
disown
