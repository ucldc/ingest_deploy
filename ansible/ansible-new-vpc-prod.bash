ansible-playbook -i hosts --extra-vars='name_suffix=-production production=True' create_new_vpc.yml &> create_prod_env.out &
disown
