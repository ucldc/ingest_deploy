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

Primary <a href="https://docs.google.com/drawings/d/18Whi3nZGNgKQ2qh-XnJlV3McItyp-skuGSqH5b_L-X8/edit">harvesting infrastructure</a> components that you'll be using.  Ask Mark Redar for access to these components:

- <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> (admin interface)
- ingest front machine
- majorTom machine
- RQ Dashboard

UCLDC Harvesting operations guide
=================================

User accounts
----------------

### Adding a monitoring user (one time set up)


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


### Adding an admin user  (one time set up)

add your public ssh to keys file in https://github.com/ucldc/appstrap/tree/master/cdl/ucldc-operator-keys.txt


From a machine that can already access the ingest front machine with ssh run:

    ansible-playbook -i hosts --vault-password-file=~/.vault_pass_ingest provision_front.yml

This will add your public key to the ~/.ssh/authorized_keys for the ec2-user on
the ingest front machine.

Running a harvest
----------------

### Queue collections for harvest

Before initiating a harvest, you'll first need to confirm if the collection has previously been harvested -- or if it's a new collection:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> (admin interface) and look up the collection, to determine the key.  For example, for <a href="https://registry.cdlib.org/admin/library_collection/collection/26189/">"Radiologic Imaging Lab collection"</a>, the key is "26189"
* Query CouchDB using this URL syntax.  Replace the key parameter with the key for the collection: `https://52.10.100.133/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name_count?key=%2226189%22`

If you have results in the resulting "value" parameter, then you'll need to remove the harvested records from CouchDB:

* Log into majorTom.
* Run this command, adding the key for the collection at the end: `python ~/code/harvester/scripts/delete_collection.py 23065`.
* The proceed with the steps below for conducting a new harvest.

If you have zero results, then you'll be conducting a new harvest:

* <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> (admin interface) and look up the collection
* Choose `Start harvest normal stage` from the `Action` drop-down. 
* You should then get feedback message verifying that the collections have been queued.

Note: "normal stage" is the current default. When you provision workers (see below), you can specify which queue(s) they will poll for jobs via the `rq_work_queues` parameter. The example given below sets the workers up to listen for jobs on `normal-stage` and `low-stage`, but you can change this if need be. 

### Harvest the collection through to CouchDB

The following sections describe the process for harvesting collections through to CouchDB. This is done via the use of "transient" <a href="http://python-rq.org/">Redis Queue</a> (RQ) worker instances, which are created as needed and then deleted after use. Once the RQ workers have been created and provisioned, they will automatically look for jobs in the queue and run the full harvester code for those jobs. The end result is that CouchDB is updated.

Note: to run these processes, you need to log onto the ingest front machine and then into the majorTom machine. Getting access to these machines is a one time setup step that Mark needs to walk you through.

#### Create workers

* Log in to the majorTom machine. 
* To activate the virtualenv in ~/workers_local/, run: `. ~/workers_local/bin/activate`
* To create some worker machines (bare ec2 instances), run: `ansible-playbook --vault-password-file=~/.vault_pass_ingest -i ~/code/ingest_deploy/ansible/hosts ~/code/ingest_deploy/ansible/create_worker-stage.yml --extra-vars="count=3"`

The `count=##` parameter will set the number of instances to create. For harvesting one small collection you can set this to `count=1`. To re-harvest all collections, you can set this to `count=20`. For anything in between, use your judgment.

You should see output in the console as the playbook runs through its tasks. At the end, it will give you a status line. Look for `fail=0` to verify that everything ran OK.

#### Provision workers

Once this is done and the instances are in a state of "running", get the machines setup and running a worker process:

* To provision the workers by installing required software, configurations
and start running Akara & the worker processes that listen on the queues
specified, run: `ansible-playbook --vault-password-file=~/.vault_pass_ingest -i ~/code/ec2.py ~/code/ingest_deploy/ansible/provision_worker-stage.yml --extra-vars='rq_work_queues=["normal-stage","low-stage"]'`

You should see the worker processes appear in the RQ dashboard once this is done. (As Mark for access to the dashboard).

NOTE: if you already have provisioned worker machines running jobs, use the
--limit=<ip range> eg. --limit=10.60.22.\* to make sure you don't reprovision 
a currently running machine. Otherwise rerunning the provisioning will put the 
current running workers in a bad state, and you will then have to log on to the 
worker and restart the worker process or terminate the machine.

AWS assigns unique subnets to the groups of workers you start, so in general,
different generations of machines will be distinguished by the different C class
subnet. This makes the --limit parameter quite useful.

#### Verify that the harvests are complete and content is in couchDB

You can monitor the jobs in the rq dashboard (ask Mark for access). The jobs will disappear from queue when they've all been slurped up by the workers. You will be able to see the workers running jobs (indicated by a "play" triangle icon) and then finishing (indicated by a "pause" icon).

You should then be able to see any changes reflected in the couchDB admin console, or via an API query. (Ask Mark for access). **_need more detail here_**

#### Delete the workers

To terminate all workers, run:

    ansible-playbook -i ~/code/ec2.py ~/code/ingest_deploy/ansible/terminate_workers.yml <--limit=10.60.?.?>
    
Again, you can use the `limit` parameter to specify a range of IP addresses for deletion.
    
### Create a New Solr Index

This section describes how to create a new solr index based on the current couchDB.

Currently, solr updates are run from the majorTom machine. The solr update
looks at the couchdb changes endpoint. This endpoint has a record for each
document that has been created in the database, including deleted documents.

To do an incremental update, run:

    /usr/local/bin/solr-update.sh

This will run an incremental update, which is what you will most often want to do. This uses the last changes sequence number that is saved in s3 at solr.ucldc/couchdb_since/<DATA_BRANCH> in order to determine what has changed.

Or, to reindex all docs run: 

    /usr/local/bin/solr-update.sh --since=0

Once the solr index is updated, push the index to S3:

    /usr/local/bin/solr-index-to-s3.sh stage
    
where `stage` is the DATA_BRANCH. (Note: right now, we are only using `stage`, so this is the default. In the future, we may have other branches, i.e. `production`.)
    
This will push the last build solr index to s3 at the location:

    solr.ucldc/indexes/<DATA_BRANCH>/YYYY/MM/solr-index.YYYY-MM-DD-HH_MM_SS.tar.bz2
    
Note that stashing a solr index on s3 does nothing in terms of updating the Calisphere front-end website. In order to update the web application so that it points to the data represented in the new index, you have to update the Elastic Beanstalk instance  configuration (see below).
    

Updating the Beanstalk (Pushing New Solr Index to Front-end)
----------------------

This section describes how to update an Elastic Beanstalk configuration to point to a new solr index. This will update the specified Calisphere front-end web application so that it points to the data in the new solr instance.

Go into the beanstalk control panel and select the ucldc-solr application.
![ucldc-solr app view](docs/images/screen_shot_ucldc_solr_app.png)
Select the existing environment you want to replace and clone the environment:
![ucldc-solr clone env](docs/images/screen_shot_clone_env.png)
If a new ami is available, choose it. Otherwise the defaults should be good. The
URL will be swapped later so the current one doesn't matter.
![ucldc-solr clone env config](docs/images/screen_shot_clone_env-config.png)
Wait for the cloning to finish, this can take a while, 15 minutes is not
unusual. Eventually you will see this:
![ucldc-solr clone env ready](docs/images/screen_shot_clone_env-ready.png)
Choose the "configuration" screen & go to the "software configuration" screen:
![ucldc-solr clone config screen](docs/images/screen_shot_clone_env-software-config.png)
Change the INDEX_PATH Environment Property to point to the new index on S3, then
click apply and wait for the new environment to be ready again. (Health should
be "Green")
Then from the environment Dashboard, select the "Rebuild Environment" action:
![ucldc-solr clone rebuild](docs/images/screen_shot_clone_env-rebuild.png)
Again this can take a while. During the rebuild, the new solr index will be
pulled to the beanstalk machines.
Now QA against the newly cloned environment's URL. Once the QA looks OK, the
final step is to swap URLs with the existing index environment. From the new
environment select the action "Swap Environment URLs". You will go to this
screen and select the currently active environment:
![ucldc-solr swap URLs](docs/images/screen_shot_clone_env-swap.png)
Click the swap button & in a few seconds the old URL will point to the new
environment.
Once everything checks out well with the new index, you can terminate the older
environment.

NOTE: need scripts to automate this.

Other AWS Related Admin Tasks
-----------------------------

### Picking up new harvester or ingest code

When new harvester or ingest code is pushed, you need to create a new generation
of worker machines to pick up the new code.

First, terminate the existing machines.

    ansible-playbook -i ~/code/ec2.py ~/code/ingest_deploy/ansible/terminate_workers.yml <--limit=10.60.?.?>

Then go through the worker create process again, creating and provisioning
machines as needed.

What to do when harvests fail
-----------------------------

First take a look at the RQ Dashboard. There will be a bit of the error message
there. Hopefully this would identify the error and you can modify whatever is
going wrong.

If you need more extensive access to logs, they are all stored on the AWS
CloudWatch platform. Go to the CloudWatch page in the AWS console and choose the
"Logs" page.
![ucldc-cw logs](docs/images/screen_shot_cloudwatch_logs_page.png)
The /var/local/rqworker & /var/local/akara contain the logs from the worker
processes & the Akara server on a worker instance.
The logs are named with the instance id & ip address, e.g. ingest-stage-i-127546c9-10.60.28.224
![ucldc-cw rqworker-log-page](docs/images/screen_shot_cloudwatch_rqworker-logs-page.png)
You will probably need to use the sorting by "Last Event Time" to get the most
recent logs. Find the log of interest by IP or instance id & click through. You
will then see the logs for that worker instance:
![ucldc-cw rqworker-log](docs/images/screen_shot_cloudwatch_rqworker-log.png)

If this doesn't get you enough information, you can ssh to a worker instance and
watch the logs real time if you like. tail -f /var/local/rqworker/worker.log or
/var/local/akara/logs/error.log.


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

