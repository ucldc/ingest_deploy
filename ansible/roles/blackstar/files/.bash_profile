# .bash_profile

# crazy pip install messup here
unset PYTHON_INSTALL_LAYOUT

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# set the harvester env vars
if [ -f ~/.harvester-env ]; then
    . ~/.harvester-env
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

# Use virtualenv by default
if [ -f ${HOME}/python2/bin/activate ]; then
    PATH=$HOME/python2/bin:${PATH}
fi

export PATH
