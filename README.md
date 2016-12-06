## Harvesting infrastructure components

<i>Consult the <a href="https://docs.google.com/drawings/d/18Whi3nZGNgKQ2qh-XnJlV3McItyp-skuGSqH5b_L-X8/edit">harvesting infrastructure diagram</a> for an illustration of the key components.  Ask Mark Redar for access to them; note that you will need to log onto the blackstar machine to run commands, using these <a href="https://sp.ucop.edu/sites/cdl/apg/OACCalisphere%20docs/dsc_putty_connection_instructions.docx">Putty connection  instructions</a> (on Sharepoint)</i>

* <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> 
* ingest front machine (*stage - harvest-stg.cdlib.org*) and ingest front machine (*production - harvest-prd.cdlib.org*), for proxy access to:
 * <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>
 * <a href="https://harvest-stg.cdlib.org/couchdb/_utils/database.html?ucldc/_all_docs">CouchDB stage</a>
 * <a href="https://harvest-prd.cdlib.org/couchdb/_utils/database.html?ucldc/_all_docs">CouchDB production</a>
 * <a href="https://harvest-stg.cdlib.org/solr/#/dc-collection/query">Solr stage</a> 
 * <a href="https://harvest-prd.cdlib.org/solr/#/dc-collection/query">Solr production</a> 
* Elastic Beanstalk 
* <a href="https://aws.amazon.com/console/">AWS CloudWatch</a>

As of February 2016, the process to publish a collection to production is as follows:

1. Create collection, add harvest URL & mapping/enrichment chain
2. Select "Queue harvest for collection on normal queue" on the registry page for the collection
3. Check that there is a worker listening on the queue. If not start one. [Stage Worker](#createstageworker)
4. Wait until the harvest job finishes, hopefully without error.  Now the collection has been harvested to the **stage CouchDB**.
5. The first round of QA in CouchDB can be performed there <a href="https://harvest-stg.cdlib.org/couchdb/_utils/database.html?ucldc/_all_docs">CouchDB stage</a>
6. Push the new CouchDB docs into the stage Solr index. Select "Queue sync solr index for collection(s) on normal-stage" on the registry page for the colleciotn [Updating Solr](#solrupdate)
7. QA **stage Solr** index in the public interface <a href="https://harvest-stg.cdlib.org/solr/#/dc-collection/query">Solr stage</a>
8. When ready to publish to production, edit Collection in the registry and check the "Ready for publication" box and save.
9. Select the "Queue sync to production couchdb for collection" [Syncing CouchDB](#synccouch)
10. Check that there is a worker in the production environment listening on the normal prod queue, if not start one. [Production Worker](#createprodworker)
11. Wait until the sync job finishes.  Now the collection has been harvested to the **production CouchDB**.
12. Sync the new docs to the **production Solr** by starting the sync from the registry for the new collections. At this point the Collection is in the *<a href="https://harvest-prd.cdlib.org/solr/#/dc-collection/query">new, candidate Calisphere Solr index</a>*
13. Once QA is done on the candidate index and ready to push new one to Calisphere, [push the index to S3](#s3index)
14. Clone the existing Solr API Elastic Beanstalk and point to the packaged index on S3
15. Swap the URL from the older Solr API Elastic Beanstalk and the new Elastic Beanstalk.


UCLDC Harvesting operations guide
=================================

###<a name="toc">CONTENTS</a>

[User accounts](#users)
* [Adding a monitoring user (one time set up)](#usermonitor)
* [Adding an admin user  (one time set up)](#useradmin)

[Preliminary setup](#prelim)
* [1. Add collection to the Registry and define harvesting endpoint](#registrycollection)
* [2. Pre-processing files from Nuxeo](#deepharvest)

[Conducting a harvest](#harvestconducting)
* [1. New harvest or re-harvest?](#harvestnew)
* [2. Create a harvest job in Registry](#harvestregistry)
* [3. Harvest the collection through to CouchDB stage](#harvestcdbstg)
* [3.1. Create stage workers](#createstageworker)
* [3.2. Provision stage workers to act on harvesting](#harvestprovisionstg)
* [3.3. Verify that the harvests are complete in CouchDB stage](#harvestcdbcomplete)
* [4. QA check collection in CouchDB stage](#harvestcdbqa)
* [5. Update Solr stage](#solrupdate)
* [5.1. Sync couchdb collection to Solr stage index, based on what's in CouchDB stage](#solrstg)
* [5.2. Delete a collection from Solr stage](#solrdelete)
* [6. Generate and review QA report for Solr stage index](#solrqa)
* [7. QA check media.json](#mediajson)
* [8. QA check in Calisphere stage UI](#calisphereqa)
* [9. Terminate stage worker instances](#terminatestg)

[Moving a harvest to production](#harvestprod)
* [1. Create a sync job in the Registry](#syncregistry)
* [2. Sync the collection through to CouchDB production](#synccdb)
* [2.1. Create production workers](#createprodworker)
* [2.2. Provision production workers to act on sync](#provisionprod)
* [3. Update Solr production](#solrprod)
* [3.1. Create a new candidate Solr index, based on what's in CouchDB production](#solrcandidate)
* [3.2. Delete a collection from candidate Solr index](#solrproddelete)
* [4. Generate and review QA report for candidate Solr index](#solrprodreport)
* [5. QA check candidate Solr index in Calisphere UI](#solrprodqa)
* [6. Terminate production worker instances](#terminateprod)

[Updating Elastic Beanstalk with candidate Solr index](#beanstalk)

[Additional resources](#addtl)
* [Removing collections/items](#removals)
* [Picking up new harvester or ingest code](#newcode)
* [Recreating the Solr Index from scratch](#solrscratch)
* [How to find a CouchDB source document for an item in Calisphere](#cdbsearch)

[Fixes for Common Problems](#commonfixes)
* [What to do when harvests fail](#failures)
* [Image problems](#imagefix)



<a name="users">User accounts</a>
----------------

### <a name="usermonitor">Adding a monitoring user (one time set up)</a>


pull the ucldc/ingest_deploy project
Get the ansible vault password from Mark. It's easiest if you create a file
(perhaps ~/.vault-password-file) to store it in and alias ansible-playbook to
ansible-playbook --vault-password-file=~/.vault-password-file. Set mode to 600)

create an htdigest entry by running

    htdigest -c tmp.pswd ingest <username>

Will prompt for password that is easy to generate with pwgen.  copy the line in tmp.pswd

Then run:

    ansible-vault --vault-password-file=~/.vault-password-file
      ingest_deploy/ansible/roles/ingest_front/vars/digest_auth_users.yml

Entries in this file are htdigest lines, preceded by a - to make a yaml list.
eg:

    ---
    digest_auth_users:
      - "u1:ingest:435srrr3db7b180366ce7e653493ca39"
      - "u1:ingest:rrrr756e5aacde0262130e79a888888c"
      - "u2:ingest:rrrr1cd0cd7rrr7a7839a5c1450bb8bc"

From a machine that can already access the ingest front machine with ssh run:

    ansible-playbook -i hosts --vault-password-file=~/.vault_pass_ingest provision_front.yml

This will install the users.digest to allow access for the monitoring user.


### <a name="useradmin">Adding an admin user  (one time set up)</a>

add your public ssh to keys file in https://github.com/ucldc/appstrap/tree/master/cdl/ucldc-operator-keys.txt


From a machine that can already access the ingest front machine with ssh run:

    ansible-playbook -i hosts --vault-password-file=~/.vault_pass_ingest provision_front.yml

This will add your public key to the ~/.ssh/authorized_keys for the ec2-user on
the ingest front machine.


<a name="prelim">Preliminary setup</a> 
--------------------------
### 1. <a name="registrycollection">Add collection to the Registry and define harvesting endpoint</a>

The first step in the harvesting process is to add the collection(s) for harvesting into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a>.  This process is described further in Section 8 of our <a href="https://sp.ucop.edu/sites/cdl/apg/_layouts/15/WopiFrame.aspx?sourcedoc=/sites/cdl/apg/OACCalisphere%20docs/dsc_maintenance_procedures.doc&action=default&DefaultItemOpen=1">OAC/Calisphere Operations and Maintenance Procedures</a>. 

When establishing the entries, you'll need to determine the harvesting endpoint: Nuxeo, OAC, or an external source.


### 2. <a name="deepharvest">Pre-processing files from Nuxeo</a>

If harvesting from Nuxeo ("deep harvesting"): once you've added the collection(s) to the Collection Registry, you'll need to complete the following steps:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection
* Choose `Queue Nuxeo deep harvest` drop-down. 

You can monitor the deep harvesting process through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>. At this stage, you'll see the harvest job listed in the queue.


<a name="harvestconducting">Conducting a harvest</a> 
--------------------------

### 1. <a name="harvestnew">New harvest or re-harvest?</a>

Before initiating a harvest, you'll first need to confirm if the collection has previously been harvested -- or if it's a new collection:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection, to determine the key.  For example, for <a href="https://registry.cdlib.org/admin/library_collection/collection/26189/">"Radiologic Imaging Lab collection"</a>, the key is "26189"
* Query CouchDB stage using this URL syntax.  Replace the key parameter with the key for the collection: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name_count?key="26189"`

If you do not have results in the "value" parameter, then go to the next step of creating a harvest job.  If you do have results in the "value" parameter, then you'll be conducting a re-harvest. You'll first need to remove the harvested records from CouchDB stage and Solr stage:

* Log onto blackstar & sudo su - hrv-stg
* Run this command to remove the collection from CouchDB stage, adding the key for the collection at the end: `delete_couchdb_collection.py 23065`.
* Then from the registry "Queue delete solr documents for collection(s) on normal-stage"
* Repeat the process above on the hrv-prd production user account, to remove the collection from CouchDB production and Solr production.
* Then proceed with the steps below for creating a new harvest job

### 2. <a name="harvestregistry">Create a harvest job in Registry</a>

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection
* Choose `Start harvest normal stage` from the `Action` drop-down. Note: "normal stage" is the current default. When you provision workers (see below), you can specify which queue(s) they will poll for jobs via the `rq_work_queues` parameter. The example given below sets the workers up to listen for jobs on `normal-stage` and `low-stage`, but you can change this if need be. 
* You should then get feedback message verifying that the collections have been queued.

You can now begin to monitor the harvesting process through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>. At this stage, you'll see the harvest job listed in the queue.

### 3. <a name="harvestcdbstg">Harvest the collection through to CouchDB stage</a>

The following sections describe the process for harvesting collections through to CouchDB stage. This is done via the use of "transient" <a href="http://python-rq.org/">Redis Queue</a>-managed (RQ) worker instances, which are created as needed and then deleted after use. Once the workers have been created and provisioned, they will automatically look for jobs in the queue and run the full harvester code for those jobs. The end result is that CouchDB is updated.

#### 3.1. Create <a name="createstageworker">stage workers</a>

* Log onto blackstar & sudo to hrv-stg
* To create some worker machines (bare ec2 instances), run: `ansible-playbook ~/code/ansible/create_worker.yml --extra-vars="count=3"`

The `count=##` parameter will set the number of instances to create. For harvesting one small collection you can set this to `count=1`. To re-harvest all collections, you can set this to `count=20`. For anything in between, use your judgment.

You should see output in the console as the playbook runs through its tasks. At the end, it will give you a status line. Look for `fail=0` to verify that everything ran OK.

The default instance creation will attempt to get instances from the "spot" market so that it is cheaper to run the workers. Sometimes the spot market price can get very high and the spot instances won't work. You can check the pricing by issuing the following command on blackstar, hrv-stg user:

```sh
aws ec2 describe-spot-price-history --instance-types m3.large --availability-zone us-west-2c --product-description "Linux/UNIX (Amazon VPC)" --max-items 2
```

Our spot bid price is set to .133 which is the current (20160803) on demand price. If the history of spot prices is greater than that or if you see large fluctuations in the pricing, you can request an on-demand instance instead by adding "ondemand=true" to the extra-vars, e.g. :

```sh
ansible-playbook ~/code/ansible/create_worker.yml --extra-vars="count=3 ondemand=True"
```

#### 3.2. <a name="harvestprovisionstg">Provision stage workers to act on harvesting</a>

Once this is done and the stage worker instances are in a state of "running", you'll need to provision the workers by installing required software, configurations and start running Akara and the worker processes that listen on the queues specified:

* Log onto blackstar & sudo su - hrv-stg
* To provision the workers, run: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml`
* Wait for the provisioning to finish; this can take a while, 5-10 minutes is not
unusual. If the provisioning process stalls, use `ctrl-C` to end the process then re-do the ansible command.
* Check the status of the the harvesting process through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>.  You should now see the provisioned workers listed, and acting on the jobs in the queue. You will be able to see the workers running jobs (indicated by a "play" triangle icon) and then finishing (indicated by a "pause" icon).

**NOTE:** if you already have provisioned worker machines running jobs, use the
`--limit=<ip range>` eg. --limit=10.60.22.\* or `--limit=<ip>,<ip>` eg. --limit=10.60.29.109,10.60.18.34 to limit the provisioning to the IPs of the newly-provisioned machines (and so you don't reprovision 
a currently running machine). Otherwise rerunning the provisioning will put the 
current running workers in a bad state, and you will then have to log on to the 
worker and restart the worker process or terminate the machine.  Example of full command: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml --limit=10.60.29.*`

AWS assigns unique subnets to the groups of workers you start, so in general,
different generations of machines will be distinguished by the different C class
subnet. This makes the --limit parameter quite useful.

#### 3.2.a <a name="workerstatus">Worker instance status

Sometimes the status of the worker instances is unclear.

You can use the ec2.py dynamic ansible inventory script with jq to parse the json to find info about the state of the worker instances.


First, refresh the cache for the dynamic inventory:

```sh
~/code/ec2.py --refresh-cache
```

To see the current IPs for the workers:

```sh
get_worker_ips.sh
```

You can then see the state of the instance by using jq to filter on the IP:

```sh
~/code/ec2.py | jq '._meta.hostvars["<ip address for instance>"].ec2_state'
```

This will tell you if it is running or not.

To get more information about the instance, just do less filtering:
```sh
~/code/ec2.py | jq -C '._meta.hostvars["<ip address for instance>"]' | less -R
```

#### 3.3. <a name="harvestcdbcomplete">Verify that the harvests are complete in CouchDB stage</a>

The jobs will disappear from queue when they've all been slurped up by the workers. You should then be able to QA check the harvested collection:

* Query CouchDB stage using this URL syntax.  Replace the key parameter with the key for the collection: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name_count?key="26189"`
* Results in the "value" parameter indicate the total number of metadata records harvested; this should align with the expected results. 
* If you have results, continue with QA checking the collection in CouchDB stage and Solr stage.
* If there are no results, you will need to troubleshoot and re-harvest.  See <b>What to do when harvests fail</b> section for details.

### 4. <a name="harvestcdbqa">QA check collection in CouchDB stage</a>

The objective of this part of the QA process is to ensure that source metadata (from a harvesting target) is correctly mapped through to CouchDB
Suggested method is to review the 1) source metadata (e.g., original MARC21  record, original XTF-indexed metadata*) vis-a-vis the 2) a random sample of CouchDB results and 3) <a href="https://docs.google.com/spreadsheets/d/1u2RE9PD0N9GkLQTFNJy3HiH9N5IbKDG52HjJ6JomC9I/edit#gid=265758929">metadata crosswalk</a>. Things to check:
* Verify if metadata from the source record was carried over into CouchDB correctly: did any metadata get dropped?
* Verify the metadata mappings: was the mapping handled correctly, going from the source metadata through to CouchDB, as defined in the metadata crosswalk?  
* Verify if any needed metadata remediation was completed (as defined in the metadata crosswalk) -- e.g., were rights statuses and statements globally applied?
* Verify DPLA/CDL required data values -- are they present?  If not, we may need to go back to the data provider to supply the information -- or potentially supply it for them (through the Collection Registry)
* Verify the data values used within the various metadata elements:
 * Do the data values look "correct" (e.g., for Type, data values are drawn from the DCMI Type Vocabulary)?  
 * Any funky characters or problems with formatting of the data?  
 * Any data coming through that looks like it may have underlying copyright issues (e.g., full-text transcriptions)?
 * Are there any errors or noticeable problems? 
   
NOTE: To view the original XTF-indexed metadata for content harvested from Calisphere:
* Go to Collection Registry, locate the collection that was harvested from XTF, and skip to the "URL harvest" field -- use that URL to generate a result of the XTF-indexed metadata (view source code to see raw XML)
* Append the following to the URL, to set the number of results: `docsPerPage=###`

#### Required Data QA Views

The Solr update process checks for a number of fields and will reject records that are missing these required values.

##### Image records without a harvested image

Objects with a sourceResource.type value of 'image' without a stored image (no 'object' field in the record) are not put into the Solr index. This view identifies these objects in couchdb.

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/image_type_missing_object
```

The base view will report total count of image type records without harvested images. To see how many per collection add "?group=true" to the URL.

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/image_type_missing_object?group=true
```

To find the number for a given collection use the "key" parameter:

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/image_type_missing_object?key="<collection id>"
```

NOTE: the double quotes are necessary in the URL.

To see the ids for the records with this issue turn off the reduce fn:

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/image_type_missing_object?key="<collection id>"&reduce=false
```

Use the include_docs parameter to add the records to the view output:

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/image_type_missing_object?key="<collection id>"&reduce=false&include_docs=true
```

##### Records missing isShownAt

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/missing_isShownAt
```

As with the above you can add various parameters to get different information in the result.

##### Records missing title

```
https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/missing_title
```

#### Querying CouchDB stage
* Generate a count of all objects for a given collection in CouchDB:  `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name_count?key="26189"`
* Generate a results set of metadata records for a given collection in CouchDB, using this URL syntax: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_list/has_field_value/by_provider_name_wdoc?key="10046"&field=originalRecord.subject&limit=100`. Each metadata record in the results set will have a unique ID  (e.g., 26094--00000001). This can be used for viewing the metadata within the CouchDB UI.
* Parameters: 
 * <b>field</b>: Optional.  Limit the display output to a particular field. 
 * <b>key</b>: Optional.  Limits by collection, using the Collection Registry numeric ID.   
 * <b>limit</b>: Optional.  Sets the number or results 
 * <b>originalRecord</b>: Optional.  Limit the display output to a particular metadata field; specify the CouchDB data element (e.g., title, creator) 
 * <b>include_docs="true"</b>: Optional.  Will include complete metadata record within the results set (JSON output) 
 * <b>value</b>:  Optional.  Search for a particular value, within a results set of metadata records from a particular collection.  Note: exact matches only!
 * <b>group=true</b>: Group the results by key
 * <b>reduce=false</b>: do not count up the results, display the individual result rows
* To generate a results set of data values within a particular element (e.g., Rights), for metadata records from all collections: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/qa_reports/_view/sourceResource.rights_value?limit=100&group_level=2`
* To check if there are null data values within a particular element (e.g., isShownAt), for metadata records from all collections: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/qa_reports/_view/isShownAt_value?limit=100&group_level=2&start_key=["__MISSING__"]`
* To view a result of raw CouchDB JSON output:  `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name?key="26094"&limit=1&include_docs=true`
* Consult the <a href="http://wiki.apache.org/couchdb/HTTP_view_API">CouchDB guide</a> for additional query details.

#### Viewing metadata for an object in CouchDB stage

* Log into <a href="https://harvest-stg.cdlib.org/couchdb/_utils/database.html?ucldc/_all_docs">CouchDB</a>
 * In the "Jump to" box, enter the unique ID for a given  metadata record (e.g., 26094--00000001)
 * You can now view the metadata in either its source format or mapped to CouchDB fields
 

### 5.<a name="solrupdate">Update Solr stage</a>

#### 5.1. <a name="solrstg">Sync couchdb collection to Solr stage index, based on what's in CouchDB stage</a>

Goto the registry page for the collection and select "Queue sync solr index for collection(s) on normal-stage". There must be a stage worker running

#### 5.2. <a name="solrdelete">Delete a collection from Solr stage</a>

From the collection registry page, select "Queue delete solr documents for collection(s) on normal-stage" and have a worker running

### 6. <a name="solrqa">QA check collection in Solr stage</a>

Generate and review a QA report for the Solr stage index, following <a href="https://github.com/mredar/ucldc_api_data_quality/tree/master/reporting">these steps</a>. The "Duplicates and missing QA spreadsheet" in particular indicates cases where harvested records lack required metadata.

Note that you can additionally view the raw results in Solr stage; this may be helpful to verify mapping issues or discrepancies in data between CouchDB and Solr stage.  Make sure you update Solr before QA'ing -- see <b>[Update Solr stage](#solrupdate)</b> instructions.

#### Querying Solr stage
* Log into <a href="https://harvest-stg.cdlib.org/solr/#/dc-collection/query">Solr</a> to conduct queries 
* Generate a count of all objects for a given collection in Solr:  `https://harvest-stg.cdlib.org/solr/dc-collection/query?q=collection_url:%22https://registry.cdlib.org/api/v1/collection/26559/%22`
* Generates counts for all collections: `https://harvest-stg.cdlib.org/solr/dc-collection/select?q=*%3A*&rows=0&wt=json&indent=true&facet=true&facet.query=true&facet.field=collection_url&facet.limit=-1&facet.sort=count`
* Consult the <a href="https://wiki.apache.org/solr/SolrQuerySyntax">Solr guide</a> for additional query details.


### 7. <a name="mediajson">QA check media.json</a>

To QA check media.json output results, use this URL syntax: `https://s3.amazonaws.com/static.ucldc.cdlib.org/media_json/70d7f57a-db0b-4a1a-b089-cce1cc289c9e-media.json`


### 8. <a name="calisphereqa">QA check in Calisphere stage UI</a>

You can preview the Solr stage index in the Calisphere UI at <a href="http://calisphere-test.cdlib.org/">http://calisphere-test.cdlib.org/</a>. Note that caching may prevent updates from immediately showing.

To immediately view results, you can QA the Solr stage index on your local workstation, following <a href="https://github.com/ucldc/public_interface">these steps</a> ("Windows install"). 

In the run.bat configuration file, point UCLDC_SOLR_URL to `https://harvest-stg.cdlib.org/solr_api`.


### 9. <a name="terminatestg">Terminate stage worker instances</a>

Once you've QA checked the results and have completed the harvest, you'll need to terminate the worker instances.

* Log into blackstar & sudo su - hrv-stg
* Run: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/terminate_workers.yml <--limit=10.60.?.?>` . You can use the `limit` parameter to specify a range of IP addresses for deletion.
* You'll receive a prompt to confirm that you want to spin down the intance; hit Return to confirm.


<a name="harvestprod">Moving a harvest to production</a>
--------------------------

### 1. <a name="synccouch">Create a sync job in the Registry</a>

Once the stage CouchDB & Solr look good and the collection looks ready to publish to Calisphere, start by syncing the stage CouchDB to the production CouchDB. The collection will then be able to be updated to production Solr.

In the Registry, edit the collection and check the box "Ready for publication" and save the collection.

Now select "Queue Sync to production CouchDB for collection" from the action on the Collection page.


### 2. <a name="synccdb">Sync the collection through to CouchDB production</a>

#### 2.1.Create <a name="createprodworker">production workers</a>

Production workers handle the syncing of the couchdb instances, so usually will not be running.
* Log onto blackstar and sudo su - hrv-prd
* To create some worker machines (bare ec2 instances), run: `ansible-playbook ~/code/ansible/create_worker.yml --extra-vars="count=1"`

The `count=##` parameter will set the number of instances to create. For harvesting one small collection you can set this to `count=1`. To re-harvest all collections, you can set this to `count=20`. For anything in between, use your judgment.

You should see output in the console as the playbook runs through its tasks. At the end, it will give you a status line. Look for `fail=0` to verify that everything ran OK.

#### 2.2. <a name="provisionprd">Provision production workers to act on sync</a>

Once this is done and the production worker instances are in a state of "running", you'll need to provision the workers by installing required software, configurations and start running Akara and the worker processes that listen on the queues specified:

* Log onto blackstar & sudo su - hrv-prd
* To provision the workers, run: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml`
* Wait for the provisioning to finish; this can take a while, 5-10 minutes is not unusual.

**NOTE:** if you already have provisioned worker machines running jobs, use the
--limit=<ip range> eg. --limit=10.60.22.\* to make sure you don't reprovision 
a currently running machine. Otherwise rerunning the provisioning will put the 
current running workers in a bad state, and you will then have to log on to the 
worker and restart the worker process or terminate the machine.  Example of full command: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml --limit=10.60.29.*`

AWS assigns unique subnets to the groups of workers you start, so in general,
different generations of machines will be distinguished by the different C class
subnet. This makes the --limit parameter quite useful.

### 3. <a name="solrprod">Update Solr production</a>

#### 3.1. <a name="solrcandidate">Create a new candidate Solr index, based on what's in CouchDB production</a>

* Synchronize the production couchdb collection to the production solr index by choosing "Queue sync solr index for collection(s) on normal-production" with a production worker instance running.

#### 3.2. <a name="solrproddelete">Delete a collection from candidate Solr index</a>

From the collection registry page, select "Queue delete solr documents for collection(s) on normal-production" and have a worker running

### 4. <a name="solrprodreport">Generate and review QA report for candidate Solr index</a>
Generate and review a QA report for the candidate Solr index, following [these steps](https://github.com/mredar/ucldc_api_data_quality/tree/master/reporting).  The main QA report in particular summarizes differences in item counts in the candidate Solr index compared with the current production index.


### 5. <a name="solrprodqa">QA check candidate Solr index in Calisphere UI</a>
You can QA the candidate Solr index on your local workstation, following [these steps](https://github.com/ucldc/public_interface) ("Windows install")

In the run.bat configuration file, point UCLDC_SOLR_URL to `https://harvest-prd.cdlib.org/solr_api`.


### 6. <a name="terminateprod">Terminate production worker instances</a>

Once you've completed syncing, you'll need to terminate the worker instances.

* Log into blackstart and sudo to hrv-prd
* Run: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/terminate_workers.yml <--limit=10.60.?.?>` . You can use the `limit` parameter to specify a range of IP addresses for deletion.
* You'll receive a prompt to confirm that you want to spin down the intance; hit Return to confirm.


<a name="beanstalk">Updating Elastic Beanstalk with candidate Solr index</a>
--------------------------

This section describes how to update an Elastic Beanstalk configuration to point to a new candidate Solr index stored on S3. This will update the specified Calisphere front-end web application so that it points to the data from Solr:

* Log onto blackstar & sudo su - hrv-prd and then follow the instructions here:
[update_beanstalk](update_beanstalk_index)
* After any new index is moved into publication, run the following commands, so that ARK URLs correctly resolve for any new incoming harvested objects with embedded ARKs: https://gist.github.com/tingletech/475ff92147b6f93f6c3f60cebdf5e507
* Last, update our Google Doc that lists out new collections that were published. (The entries can be cut-and-pasted from the <a href="https://github.com/mredar/ucldc_api_data_quality/tree/master/reporting">QA reporting spreadsheet</a>): https://docs.google.com/spreadsheets/d/1FI2h6JXrqUdONDjRBETeQjO_vkusIuG5OR5GWUmKp1c/edit#gid=0 . Sherri uses this Google Doc for CDLINFO postings, highlighting newly-published collections.

TODO: add how to run the QA spreadsheet generating code


<a name="addtl">Additional resources</a> 
--------------------------

###<a name="removals">Removing collections/items from publication</a>

#### <a name="removalitem">Individual items</a>

* Log into CouchDB stage; search for and delete the specific item record
* Then run this command, to update Solr stage: `/usr/local/bin/solr-update.sh`
* Repeat the process on CouchDB production

-or-

* Create a list of the CouchDB identifiers for the items, and add them to a file (one per line)
* Run `delete_couchdb_id_list.py` with the file as input:`delete_couchdb_id_list.py <file with list of ids>`

#### <a name="removalcollection">Entire collection</a>

* Log onto blackstar & sudo su - hrv-prd
* Run this command to remove the collection from CouchDB stage, adding the key for the collection at the end: `delete_couchdb_collection.py 23065`.
* Then from the registry "Queue delete solr documents for collection(s) on normal-production"
* Follow the process of sync'ing the collection through to CouchDB production


### <a name="newcode">Picking up new harvester or ingest code</a>

When new harvester or ingest code is pushed, you need to create a new generation
of worker machines to pick up the new code:

* First, terminate the existing machines: `ansible-playbook -i ~/code/ec2.py ~/code/ingest_deploy/ansible/terminate_workers.yml <--limit=10.60.?.?>`
* Then go through the worker create process again, creating and provisioning
machines as needed.

###<a name="solrscratch">Recreating the Solr Index from scratch</a>

The solr index is run in a docker container. To make changes to the schema or
other configurations, you need to recreate the docker image for the container.

NOTE: THIS NEEDS UPDATING
To do so in the ingest environment, run `ansible-playbook -i hosts solr_docker_rebuild.yml`.  This will remove the docker container & image, rebuild the image, remove the index files and run a new container based on the latest solr config in https://github.com/ucldc/solr_api/.

You will then have to run `/usr/local/solr-update.sh --since=0` to reindex the
whole couchdb database.

###<a name="cdbsearch">How to find a CouchDB source document for an item in Calisphere</a>

#### See the new tool for automating this here: https://github.com/mredar/ucldc_api_data_quality/blob/master/reporting/README.md

Tracing back to the document source in CouchDB is critical to diagnose problems with data and images.

Get the Solr id for the item. This is the part of the URL after the /item/ without the final slash. For https://calisphere.org/item/32e2220c1e918cf17f0597d181fa7e3e/, the Solr ID is 32e2220c1e918cf17f0597d181fa7e3e.

Now go to the Solr index of interest and query for the id:
https://harvest-stg.cdlib.org/solr/dc-collection/select?q=32e2220c1e918cf17f0597d181fa7e3e&wt=json&indent=true

Find the `harvest_id_s` value, in this case "26094--LAPL00050887". Then plug this into CouchDB for the ucldc database:
https://harvest-stg.cdlib.org/couchdb/ucldc/26094--LAPL00050887 (or with the UI - https://harvest-stg.cdlib.org/couchdb/_utils/document.html?ucldc/26094--LAPL00050887)

<a name="commonfixes">Fixes for Common Problems</a>
-------------------------

### <a name="failures">What to do when harvests fail</a>

First take a look at the RQ Dashboard. There will be a bit of the error message
there. Hopefully this would identify the error and you can modify whatever is
going wrong.

If you need more extensive access to logs, they are all stored on the AWS
CloudWatch platform. 
The /var/local/rqworker & /var/local/akara contain the logs from the worker
processes & the Akara server on a worker instance.
The logs are named with the instance id & ip address, e.g. ingest-stage-i-127546c9-10.60.28.224

From the blackstar machine you can access the logs on CloudWatch using the scripts in the bin directory

First, get the IPs of the worker machines by running `get_worker_ips.sh`

Then for the worker whose logs you want to examine:
`get_log_events_for_rqworker.sh <worker ip>`

This is an output of the rqworker log, for the akara log use:
`get_log_events_for_akara.sh <worker ip>`

If you need to go back further in the log history, for now ask Mark.

If this doesn't get you enough information, you can ssh to a worker instance and
watch the logs real time if you like. tail -f /var/local/rqworker/worker.log or
/var/local/akara/logs/error.log.

### <a name="imagefix">Image problems</a>

The image harvesting part of the process often has at least partial failures.
First, just try to run the image harvest for the collection again from the registry. Hopefully that fixes.

If incorrect images were downloaded, you must manually queue the image harvest to force it to re-fetch images that were found. First, you need to clear the "CouchDB ID -> image url" cache and then set the image harvest to run with the flag --get_if_object (so get the image even if the "object" field exists in the CouchDB document)

First you should check that the `isShownBy` field for the documents in question point to valid images. See [Finding CouchDB Doc for item](#cdbdocforitem) to find the document.

* Log onto blackstar & sudo su - hrv-stg
* Run `python ~/code/harvester/scripts/redis_delete_harvested_images_script.py <collection_id>`. This will produce a file called `delete_image_cache-<collection_id>` in the current directory.
* Run `~/redis-3.0.2/src/redis-cli -h $REDIS_HOST < delete_image_cache-<collection_id>`. This will clear the cache of previously harvested URLs.
* Run `python ~/code/harvester/scripts/queue_image_harvest.py mredar@gmail.com normal-stage https://registry.cdlib.org/api/v1/collection/<collection_id>/ --get_if_object`
* Keep your fingers crossed

Development
-----------

ingest_deploy
-------------

Ansible, packer and vagrant project for building and running ingest environment
on AWS and locally.
Currently only the ansible is working, need to get a local vagrant version
working....

### Dependencies

#### Tools

- [Ansible](http://www.ansible.com/home) (Version X.X)

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

