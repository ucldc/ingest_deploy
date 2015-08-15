ingest_deploy
=============

Ansible, packer and vagrant project for building and running ingest environment
on AWS and locally.
Currently only the ansible is working, need to get a local vagrant version
working....

### Dependencies

Tools:

- [VirtualBox](https://www.virtualbox.org/) (Version X.X)
- [Vagrant](https://www.vagrantup.com/) (Version X.X)
- [vagrant-vbguest](https://github.com/dotless-de/vagrnat-vbguest/) (`vagrant plugin install vagrant-vbguest`)
- [Ansible](http://www.ansible.com/home) (Version X.X)
- if using VirtualBox, install the vagrant-vbguest 

UCLDC Harvesting operations guide
=================================


add monitoring user
--------------------------------

pull the ucldc/ingest_deploy project
Get the ansible vault password from Mark. It's easiest if you create a file
(perhaps ~/.vault-password-file) to store it in and alias ansible-playbook to
ansible-playbook --vault-password-file=~/.vault-password-file. Set mode to 600)

create an htdigest entry by running

    htdigest -c tmp.pswd ingest <username>

Will prompt for password that is easy to generate with pwgen.  copy the line in tmp.pswd

Then run:

    ansible-vault --vault-password-file=~/.vault-password-file
      ingest_deploy/ansible/roles/ingest_front/vars/basic_auth_users.yml

Entries in this file are htdigest lines, preceded by a - to make a yaml list.
eg:

    ---
    basic_auth_users:
      - "u1:ingest:435srrr3db7b180366ce7e653493ca39"
      - "u1:ingest:rrrr756e5aacde0262130e79a888888c"
      - "u2:ingest:rrrr1cd0cd7rrr7a7839a5c1450bb8bc"

From a machine that can already access the ingest front machine with ssh run:

    ansible-playbook -i hosts --vault-password-file=~/.vault_pass_ingest provision_front.yml

This will install the users.digest to allow access for the monitoring user.


Adding an admin user
--------------------

add your public ssh to keys file in https://github.com/ucldc/appstrap/tree/master/cdl/ucldc-operator-keys.txt


From a machine that can already access the ingest front machine with ssh run:

    ansible-playbook -i hosts --vault-password-file=~/.vault_pass_ingest provision_front.yml

This will add your public key to the ~/.ssh/authorized_keys for the ec2-user on
the ingest front machine.


Creating workers
----------------

You need to log onto the ingest front machine and then to the majorTom machine.
The key to access instances in the private subnet has a password, ask Mark for
it.

Log in to the majorTom machine. From here you can run the ansible playbooks to
create and provision worker machines.

First you need to activate the virtualenv in ~/workers_local/ 

    . ~/workers_local/bin/activate

Then to create some worker machines run:

    ansible-playbook --vault-password-file=~/.vault_pass_ingest -i ~/code/ingest_deploy/ansible/hosts ~/code/ingest_deploy/ansible/create_worker-stage.yml --extra-vars="count=3"

The "count=##" will set the number of instances to create.
Once this runs and the instances are in a state of "running", to get the
machines setup & running a worker process run:

    ansible-playbook --vault-password-file=~/.vault_pass_ingest -i ~/code/ec2.py ~/code/ingest_deploy/ansible/provision_worker-stage.yml --extra-vars='rq_work_queues=["normal-stage","low-stage"]'

This will provision the workers by installing required software, configurations
and start running Akara & the worker processes that listen on the queues
specified. You should see the worker processes appear in the rq monitor once
this is done.

NOTE: if you already have provisioned worker machines running jobs, use the
--limit=<ip range> eg. --limit=10.60.22.\*. Rerunning the provisioning will put
the current running workers in a bad state, you will then have to log on to the
worker and restart the worker process or terminate the machine.

AWS assigns unique subnets to the groups of workers you start, so in general,
different generations of machines will be distinguished by the different C class
subnet. This makes the --limit parameter quite useful.


Creating New Solr Indexes
-------------------------

Currently, solr updates are run from the majorTom machine. The solr update
looks at the couchdb changes endpoint. This endpoint has a record for each
document that has been created in the database, including deleted documents.

Run

    /usr/local/bin/solr-update.sh <--since=(int)>

This will run an incremental update from the last changes sequence number that is saved in s3 at solr.ucldc/couchdb_since/<DATA_BRANCH>.

To specify the last sequence number (since parameter to the couchdb change
endpoint). To reindex all docs use --since=0

Once the solr index is updated, run:

    /usr/local/bin/solr-index-to-s3.sh <DATA_BRANCH> (stage|production)

This will push the last build solr index to s3 at the location

    solr.ucldc/indexes/<DATA_BRANCH>/YYYY/MM/solr-index.YYYY-MM-DD-HH_MM_SS.tar.bz2

Updating the Beanstalk
----------------------

Go into the beanstalk control panel and clone an existing ucldc-solr-stage
environment in the ucldc-solr application. Go into the configuration page and
change the environment variable INDEX_PATH to point to the new index.
Once the environment is updated, run a "Rebuild Environment". Building the
environment will recreate the machines and run the AWS eb commands that download
the INDEX_PATH file and run the solr index on that.


Other AWS Related Admin Tasks
-----------------------------

When new harvester or ingest code is pushed, you need to crate a new generation
of worker machines to pick up the new code.

First, terminate the existing machines.

    ansible-playbook -i ~/code/ec2.py ~/code/ingest_deploy/ansible/terminate_workers.yml <--limit=10.60.?.?>

Then go through the worker create process again, creating and provisioning
machines as needed.

License
=======

Copyright © 2015, Regents of the University of California
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, 
  this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, 
  this list of conditions and the following disclaimer in the documentation 
  and/or other materials provided with the distribution.
- Neither the name of the University of California nor the names of its
  contributors may be used to endorse or promote products derived from this 
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.
