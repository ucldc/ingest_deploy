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
3. Check that there is a worker listening on the queue. If not start one. [Stage Worker](#startstageworker)
4. Wait until the harvest job finishes, hopefully without error.  Now the collection has been harvested to the **stage CouchDB**.
5. The first round of QA in CouchDB can be performed there <a href="https://harvest-stg.cdlib.org/couchdb/_utils/database.html?ucldc/_all_docs">CouchDB stage</a>
6. Push the new CouchDB docs into the stage Solr index. Select "Queue sync solr index for collection(s) on normal-stage" on the registry page for the colleciotn [Updating Solr](#solrupdate)
7. QA **stage Solr** index in the public interface <a href="https://harvest-stg.cdlib.org/solr/#/dc-collection/query">Solr stage</a>
8. When ready to publish to production, edit Collection in the registry and check the "Ready for publication" box and save.
9. Select the "Queue sync to production couchdb for collection" [Syncing CouchDB](#synccouch)
10. Check that there is a worker in the production environment listening on the normal prod queue, if not start one. [Production Worker](#startprodworker)
11. Wait until the sync job finishes.  Now the collection has been harvested to the **production CouchDB**.
12. Sync the new docs to the **production Solr** by starting the sync from the registry for the new collections. At this point the Collection is in the *<a href="https://harvest-prd.cdlib.org/solr/#/dc-collection/query">new, candidate Calisphere Solr index</a>*
13. Once QA is done on the candidate index and ready to push new one to Calisphere, [push the index to S3](#s3index)
14. Clone the existing Solr API Elastic Beanstalk and point to the packaged index on S3
15. Swap the URL from the older Solr API Elastic Beanstalk and the new Elastic Beanstalk.


UCLDC Harvesting operations guide
=================================

### <a name="toc">CONTENTS</a>

[User accounts](#users)
* [Adding a monitoring user (one time set up)](#usermonitor)
* [Adding an admin user  (one time set up)](#useradmin)

[Preliminary steps: add collection to the Collection Registry and define harvesting endpoint](#registrycollection)

[Conducting a harvest to stage](#harvestconducting)
* [1. Managing workers to process harvesting jobs](#workeroverview)
* [1.1. Start stage workers](#startstageworker)
* [1.2. Checking the status of a worker](#workerstatus)
* [1.3. Stop or terminate stage worker instances](#terminatestg)
* [2. Run harvest jobs: non-Nuxeo sources](#harvestregistry)
* [2.1. New harvest or re-harvest?](#harvestnew)
* [2.2. Harvest metadata to CouchDB stage](#harvestcdbstg)
* [2.3. Harvest preview and thumbnail images](#harvestpreview)
* [3. Run harvest jobs: Nuxeo](#harvestnuxeostg)
* [3.1. New harvest or re-harvest?](#harvestnew1)
* [3.2. Harvest and process access files from Nuxeo ("deep harvesting")](#deepharvest)
* [3.3. Harvest metadata to CouchDB stage](#harvestnuxmdstg)
* [3.4. Harvest preview image, also used for thumbnails](#harvestnuxpreview)
* [3.5. QA check number of objects harvested from Nuxeo](#nuxeoqa)
* [4. QA check collection in CouchDB stage](#harvestcdbqa)
* [4.1. Check the number of records in CouchDB](#harvestcdbcomplete)
* [4.2. Additional QA checking](#couchdbaddqa)
* [5. Sync CouchDB stage to Solr stage](#solrupdate)
* [6. QA check collection in Solr stage](#solrqa)
* [7. QA check in Calisphere stage UI](#calisphereqa) 

[Moving a harvest to production](#harvestprod)
* [8. Manage workers to process harvesting jobs](#startprodworker)
* [9. Sync the collection from CouchDB stage to CouchDB production](#synccouch)
* [10. Sync the collection from CouchDB production to Solr production](#synccdb)
* [11. QA check candidate Solr index in Calisphere UI](#solrprodqa)
* [12. Generate and review QA report for candidate Solr index](#solrprodreport)

[Updating Elastic Beanstalk with candidate Solr index](#beanstalk)

[Removing items or collections (takedown requests)](#removals)

[Restoring collections from production](#restores)

[Additional resources](#addtl)
* [Running long processes](#longprocess)
* [Picking up new harvester or ingest code](#newcode)
* [Recreating the Solr Index from scratch](#solrscratch)
* [How to find a CouchDB source document for an item in Calisphere](#cdbsearch)
* [Editing or deleting individual items](#editnforgetit)
* [Creating/Harvesting with High Stage Workers](#highstage)

[Fixes for Common Problems](#commonfixes)
* [What to do when harvests fail](#failures)
* [Image problems](#imagefix)

[Addendum: Creating new AMI images - Developers only]


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


<a name="registrycollection">Preliminary steps: add collection to the Collection Registry and define harvesting endpoint</a>
--------------------------

The first step in the harvesting process is to add the collection(s) for harvesting into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a>.  This process is described further in Section 8 of our <a href="https://sp.ucop.edu/sites/cdl/apg/_layouts/15/WopiFrame.aspx?sourcedoc=/sites/cdl/apg/OACCalisphere%20docs/dsc_maintenance_procedures.doc&action=default&DefaultItemOpen=1">OAC/Calisphere Operations and Maintenance Procedures</a>. 

When establishing the entries, you'll need to determine the harvesting endpoint: Nuxeo, OAC, or an external source.


<a name="harvestconducting">Conducting a harvest to stage</a> 
-------------------------

### 1. <a name="workeroverview">Managing workers to process harvesting jobs</a>

We use "transient" <a href="http://python-rq.org/">Redis Queue</a>-managed (RQ) worker instances to process harvesting jobs in either a staging or production environment. They can be created as needed and then deleted after use. Once the workers have been created and provisioned, they will automatically look for jobs in the queue and run the full harvester code for those jobs.

#### 1.1. <a name="startstageworker">Start stage workers</a>

* Log onto blackstar and run `sudo su - hrv-stg`
* To start some worker machines (bare ec2 spot instances), run: `ansible-playbook ~/code/ansible/start_ami.yml --extra-vars="count=1"` . 
  * For on-demand instances, run: `snsatnow ansible-playbook ~/code/ansible/start_ami_ondemand.yml --extra-vars="count=1"`
  * For an extra large (and costly!) on-demand instance (e.g., m4.2xlarge, m4.4xlarge), run: `ansible-playbook ~/code/ansible/start_ami_ondemand.yml --extra-vars="worker_instance_type=m4.2xlarge"` .  *If you create an extra large instance, make sure you terminate it after the harvesting job is completed!*

The `count=##` parameter will set the number of instances to create. For harvesting one small collection you can set this to `count=1`. To re-harvest all collections, you can set this to `count=20`. For anything in between, use your judgment.


The default instance creation will attempt to get instances from the "spot" market so that it is cheaper to run the workers. Sometimes the spot market price can get very high and the spot instances won't work. You can check the pricing by issuing the following command on blackstar, hrv-stg user:

```sh
aws ec2 describe-spot-price-history --instance-types m3.large --availability-zone us-west-2c --product-description "Linux/UNIX (Amazon VPC)" --max-items 2
```

Our spot bid price is set to .133 which is the current (20160803) on demand price. If the history of spot prices is greater than that or if you see large fluctuations in the pricing, you can request an on-demand instance instead by running the ondemand playbook : (NOTE: the backslash \ is required)

```sh
ansible-playbook ~/code/ansible/start_ami_ondemand.yml --extra-vars="count=3"
```



#### 1.2. <a name="workerstatus">Checking the status of a worker</a>

Sometimes the status of the worker instances is unclear.

To check the processing status for a given worker, log into Blackstar and SSH to the particular stage or prod machine.

    cd to /var/local/rqworker and locate the worker.log file.
    Run tail -f worker.log to view the logs.

You can also use the ec2.py dynamic ansible inventory script with jq to parse the json to find info about the state of the worker instances.


First, refresh the cache for the dynamic inventory:

```sh
~/code/ec2.py --refresh-cache
```

To see the current info for the workers:

```sh
get_worker_info.sh
```

This will report the running or not state, the IPs, ec2 IDs & the size of workers.

You can then see the state of the instance by using jq to filter on the IP:

```sh
~/code/ec2.py | jq '._meta.hostvars["<ip address for instance>"].ec2_state'
```

This will tell you if it is running or not.

To get more information about the instance, just do less filtering:
```sh
~/code/ec2.py | jq -C '._meta.hostvars["<ip address for instance>"]' | less -R
```

#### 1.3. <a name="terminatestg">Stop or terminate stage worker instances</a>

Once harvesting jobs are completed (see steps below), terminate the worker instances.

* Log into blackstar and run `sudo su - hrv-stg`
* To just stop instances, run `ansible-playbook
* Run: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/terminate_workers.yml <--limit=10.60.?.?>` . You can use the `limit` parameter to specify a range of IP addresses for deletion.
* To force terminate an instance, append `--tags=terminate-instances`
* You'll receive a prompt to confirm that you want to spin down the intance; hit Return to confirm.

We should now leave *one* instance in a "stopped" state. Terminate all but one of the instances then run:

```sh
ansible-playbook -i ~/code/ec2.py ~/code/ansible/stop_workers.yml
```

This will stop the instance so it can be brought up easily. `get_worker_info.sh` should report the instance as "stopping" or "stopped".

As a last option for terminating unresponsive workers, run `get_worker_info.sh` to get the worker ID (i-[whatever]) then use the following command `aws ec2 terminate-instances --instance-ids "[XXXXX]"` . If you can SSH to the worker, you can also use `ec2-metadata` to determine the worker ID.


### 2. <a name="harvestregistry">Run harvest jobs: non-Nuxeo sources</a>


#### 2.1. <a name="harvestnew">New harvest or re-harvest?</a>

Before initiating a harvest, confirm if the collection has previously been harvested -- or if it's a new collection.  

If the collection has previously been harvested and is viewable in the Calisphere stage UI (http://calisphere-data.cdlib.org/), then delete the collection from CouchDB stage and Solr stage:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection
* Run `Queue deletion of documents from CouchDB stage`. 
* Then run `Queue deletion of documents from Solr stage`.
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can use the following command syntaxes on the dsc-blackstar role account:

`./bin/delete_couchdb_collection.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26275`
`./bin/queue_delete_solr_collection.py adrian.turner@ucop.edu high-stage 26275`

#### 2.2. <a name="harvestcdbstg">Harvest metadata to CouchDB stage</a>

This process will harvest metadata from the target system into a resulting CouchDB record.

* From the Collection Registry, select `Queue harvest to CouchDB stage` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can use the following command syntax on the dsc-blackstar role account:

`queue_harvest.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26943`


#### 2.3. <a name="harvestpreview">Harvest preview and thumbnail images</a>

This process will hit the URL referenced in `isShownAt` in the CouchDB record to derive a small preview image (used for the object landing page); that preview image is also used for thumbnails in search/browse and related item results.

* From the Collection Registry, select `Queue image harvest` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can run use the following command syntax on the dsc-blackstar role account:

`queue_image_harvest.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26943`



### 3. <a name="harvestnuxeostg">Run harvest jobs: Nuxeo</a>

#### 3.1. <a name="harvestnew1">New harvest or re-harvest?</a>

Before initiating a harvest, confirm if the collection has previously been harvested -- or if it's a new collection.  

If the collection has previously been harvested and is viewable in the Calisphere stage UI (http://calisphere-data.cdlib.org/), then delete the collection from CouchDB stage and Solr stage:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection
* Run `Queue deletion of documents from CouchDB stage`. 
* Then run `Queue deletion of documents from Solr stage`.
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can use the following command syntaxes on the dsc-blackstar role account:

`./bin/delete_couchdb_collection.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26275`
`./bin/queue_delete_solr_collection.py adrian.turner@ucop.edu high-stage 26275`

#### 3.2. <a name="deepharvest">Harvest and process access files from Nuxeo ("deep harvesting")</a>

The process pulls files from the "Main Content File" section in Nuxeo, and formats them into access files for display in Calisphere. If you only need to pick up metadata changes in Nuxeo, skip this step. Here's what the process does:

1. It stashes a high quality copy of any associated media or text files on S3.  These files appear on the object landing page, for interactive viewing:
* If image, creates a zoomable jp2000 version and stash it on S3 for use with our IIIF-compatible Loris server. Tools used to convert the image include ImageMagick and Kakadu
* If audio, stashes mp3 on s3.
* If file (i.e. PDF), stashes on s3
* If video, stashes mp4 on s3

2. Creates a small preview image (used for the object landing page) and complex object component thumbnails and stashes on S3. For these particular formats, it does the following:
* If video, creates a thumbnail and stash on S3. Thumbnail is created by capturing the middle frame of the video using the ffmpeg tool.
* If PDF, creates a thumbnail and stash on S3. Thumbnail is created by creating an image of the first page of the PDF, using ImageMagick.

3. Compiles full metadata and structural information (such as component order) for all complex objects, in the form of a `media.json` file.  To view the media.json for a given object, use this URL syntax (where <UID> is the Nuxeo unique identifier, e.g., 70d7f57a-db0b-4a1a-b089-cce1cc289c9e): `https://s3.amazonaws.com/static.ucldc.cdlib.org/media_json/<UID>-media.json`

To run the "deep harvest" process:

* Log into the <a href="https://registry.cdlib.org/admin/library_collection/collection/">Collection Registry</a> and look up the collection
* Run `Queue Nuxeo deep harvest` drop-down. 
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can run use the following command syntax on the dsc-blackstar role account:

`queue_deep_harvest.py adrian.turner@ucop.edu high-stage 26959`

If you want to deep harvest content from a folder in Nuxeo that isn't set up in the Registry as a collection, you can run the following command on the dsc-blackstar role account. Omit the `--replace` flag if you don't want to replace existing files on S3:

```shell
python queue_deep_harvest_folder.py adrian.turner@ucop.edu high-stage '/asset-library/UCOP/Folder Name' --replace
```

If there are problems with individual items, you can do a deep harvest for just one doc (not including any components) by its Nuxeo path. You need to log onto dsc-blackstar and sudo to the hrv-stg role account. Then:

```shell
queue_deep_harvest_single_object.py "<path to assest wrapped with quotes>"
```
e.g. 
```shell
queue_deep_harvest_single_object.py "/asset-library/UCR/Manuscript Collections/Godoi/box_01/curivsc_003_001_005.pdf"
```

This will run 4 jobs, one for grabbing files, one for creating jp2000 for access & IIIF, one to create thumbs and finally a job to produce the media_json file.

You can also do a deep harvest for one Nuxeo object, including any components, by providing its Nuxeo path. You need to log onto dsc-blackstar and sudo to the hrv-stg role account. Then:

```shell
python queue_deep_harvest_single_object_with_components.py adrian.turner@ucop.edu normal-stage "<path to asset wrapped with quotes>"
```

You can run a deep harvest on one previously harvested Nuxeo object (including components) and replace it by logging into dsc-blackstar with the hrv-stg role account and using the --replace switch (if it doesn't have components, use `queue_deep_harvest_single_object.py`)

e.g. 
```shell
python queue_deep_harvest_single_object_with_components.py adrian.turner@ucop.edu normal-stage "<path to asset wrapped quotes>" --replace 

```

#### 3.3. <a name="harvestnuxmdstg">Harvest metadata to CouchDB stage</a>

This process will harvest metadata from Nuxeo into a resulting CouchDB record.

* From the Collection Registry, select `Queue harvest to CouchDB stage` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can use the following command syntax on the dsc-blackstar role account:

`queue_harvest.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26943`

#### 3.4. <a name="harvestnuxpreview">Harvest preview image, also used for thumbnails</a>

This process will hit the URL referenced in `isShownBy` in the CouchDB record to derive a small preview image (used for the object landing page); that preview image is also used for thumbnails in search/browse and related item results.

* From the Collection Registry, select `Queue image harvest` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can run use the following command syntax on the dsc-blackstar role account:

`queue_image_harvest.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26943`

If there are problems with individual items, you can run the process on a specific object (or multiple objects) by referencing the harvest ID. You need to log onto dsc-blackstar and sudo to the hrv-stg role account. Then:

`python ~/bin/queue_image_harvest_for_doc_ids.py mredar@gmail.com normal-stage 23065--http://ark.cdlib.org/ark:/13030/k600073n`

For multiple items, separate the harvest IDs with commas:

`python ~/bin/queue_image_harvest_for_doc_ids.py mredar@gmail.com normal-stage 23065--http://ark.cdlib.org/ark:/13030/k600073n,23065--http://ark.cdlib.org/ark:/13030/k6057mxb`

### 3.5. <a name="nuxeoqa">QA check number of objects harvested from Nuxeo</a>

To generate a count of the total number of Nuxeo objects harvested (simple objects + complex objects, minus components):

* Log into blackstar and run `sudo su - hrv-stg`
* Run `python /home/hrv-stg/code/nuxeo-calisphere/utils/get_collection_object_count.py '/asset-library/UCM/Ramicova'`. (Replace the path with the particular project folder for the harvested collection)


### 4. <a name="harvestcdbqa">QA check collection in CouchDB stage</a>


#### 4.1. <a name="harvestcdbcomplete">Check the number of records in CouchDB</a>

* Query CouchDB stage using this URL syntax.  Replace the key parameter with the key for the collection: `https://harvest-stg.cdlib.org/couchdb/ucldc/_design/all_provider_docs/_view/by_provider_name_count?key="26189"`
* Results in the "value" parameter indicate the total number of metadata records harvested; this should align with the expected results. 
* If you have results, continue with QA checking the collection in CouchDB stage and Solr stage.
* If there are no results, you will need to troubleshoot and re-harvest.  See <b>What to do when harvests fail</b> section for details.


#### 4.2. <a name="couchdbaddqa">Additional QA checking</a>

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
 

### 5. <a name="solrupdate">Sync CouchDB stage to Solr stage</a>

This process will update the Solr stage index with records from CouchDB stage:

* From the Collection Registry, select `Queue sync from CouchDB stage to Solr stage` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.


If you need more control of the process (i.e. to put on a different queue),
you can run the queue_sync_to_solr.py on dsc-blackstar role account:

```shell
queue_sync_to_solr.py mredar@gmail.com high-stage 26943
```

### 6. <a name="solrqa">QA check collection in Solr stage</a>

You can view the raw results in Solr stage; this may be helpful to verify mapping issues or discrepancies in data between CouchDB and Solr stage.  

* Log into <a href="https://harvest-stg.cdlib.org/solr/#/dc-collection/query">Solr</a> to conduct queries 
* Generate a count of all objects for a given collection in Solr:  `https://harvest-stg.cdlib.org/solr/dc-collection/query?q=collection_url:%22https://registry.cdlib.org/api/v1/collection/26559/%22`
* Generates counts for all collections: `https://harvest-stg.cdlib.org/solr/dc-collection/select?q=*%3A*&rows=0&wt=json&indent=true&facet=true&facet.query=true&facet.field=collection_url&facet.limit=-1&facet.sort=count`
* Consult the <a href="https://wiki.apache.org/solr/SolrQuerySyntax">Solr guide</a> for additional query details.



### 7. <a name="calisphereqa">QA check in Calisphere stage UI</a>

You can preview the Solr stage index in the Calisphere UI at <a href="http://calisphere-data.cdlib.org/">http://calisphere-data.cdlib.org/</a>. 

To immediately view results, you can QA the Solr stage index on your local workstation, following <a href="https://github.com/ucldc/public_interface">these steps</a> ("Windows install"). In the run.bat configuration file, point UCLDC_SOLR_URL to `https://harvest-stg.cdlib.org/solr_api`.


<a name="harvestprod">Moving a harvest to production</a>
--------------------------

### 8. <a name="startprodworker">Manage workers to process harvesting jobs</a>

Follow the steps outlined above for [starting and managing worker instances](#workeroverview) -- but once logged into blackstar, use `sudo su - hrv-prd` to create workers in the production environment.


### 9. <a name="synccouch">Sync the collection from CouchDB stage to CouchDB production</a>

Once the CouchDB and Solr stage data looks good and the collection looks ready to publish to Calisphere, start by syncing CouchDB stage to the CouchDB production:

* In the Registry, edit the collection and check the box "Ready for publication" and save the collection.
* Then select `Queue Sync to production CouchDB for collection` from the action on the Collection page.

If you need more control of the process (i.e. to put on a different queue),
you can run the queue_sync_couchdb_collection.py on dsc-blackstar role account:

```shell
./bin/queue_sync_couchdb_collection.py mredar@gmail.com high-stage https://registry.cdlib.org/api/v1/collection/26681/
```

### 10. <a name="synccdb">Sync the collection from CouchDB production to Solr production</a>

This process will update the Solr production index ("candidate Solr index") with records from CouchDB production:

* From the Collection Registry, select `Queue sync from CouchDB production to Solr production` 
* You should then get feedback message verifying that the collections have been queued
* You can track the progress through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>; once the jobs are done, a results report will be posted to the #dsc_harvesting_report channel in Slack.

If you need more control of the process (i.e. to put on a different queue),
you can run the queue_sync_to_solr.py on dsc-blackstar role account:

```shell
queue_sync_to_solr.py mredar@gmail.com high-stage 26943
```


### 11. <a name="solrprodqa">QA check candidate Solr index in Calisphere UI</a>

You can preview the candidate Solr index in the Calisphere UI at <a href="http://calisphere-test.cdlib.org/">http://calisphere-test.cdlib.org/</a>. 

To immediately view results, you can QA the Solr stage index on your local workstation, following <a href="https://github.com/ucldc/public_interface">these steps</a> ("Windows install"). In the run.bat configuration file, point UCLDC_SOLR_URL to `https://harvest-prd.cdlib.org/solr_api`.


### 12. <a name="solrprodreport">Generate and review QA report for candidate Solr index</a>

Generate and review a QA report for the candidate Solr index, following [these steps](https://github.com/ucldc/ucldc_api_data_quality/tree/master/reporting).  The main QA report in particular summarizes differences in item counts in the candidate Solr index compared with the current production index.

If there is a *drop* in the number of objects for a given collection, we need to be able to justify why that happened -- e.g., contributor intentionally needed to remove items. If there is a justified reason for the removal of objects, we also need to double check if those removed items are associated with any Calisphere exhibitions. (Need info. here on how to generate link report for exhibitions).


<a name="beanstalk">Updating Elastic Beanstalk with candidate Solr index</a>
--------------------------

This section describes how to update an Elastic Beanstalk configuration to point to a new candidate Solr index stored on S3. This will update the specified Calisphere front-end web application so that it points to the data from Solr:

* Log onto blackstar & sudo su - hrv-prd and then follow the instructions here:
[update_beanstalk](update_beanstalk_index)
* After any new index is moved into publication:
  * Run the following commands, so that ARK URLs correctly resolve for any new incoming harvested objects with embedded ARKs: https://gist.github.com/tingletech/475ff92147b6f93f6c3f60cebdf5e507
  * Run the following command, to generate <a href="https://help.oac.cdlib.org/support/solutions/articles/9000185982-metadata-analysis-reports-for-collections">metadata analysis reports</a> based on the new index: `snsatnow ./bin/solrdump-to-s3.sh`
* Last, update our Google Doc that lists out new collections that were published. (The entries can be cut-and-pasted from the <a href="https://github.com/mredar/ucldc_api_data_quality/tree/master/reporting">QA reporting spreadsheet</a>): https://docs.google.com/spreadsheets/d/1FI2h6JXrqUdONDjRBETeQjO_vkusIuG5OR5GWUmKp1c/edit#gid=0 . Sherri uses this Google Doc for CDLINFO postings, highlighting newly-published collections.

TODO: add how to run the QA spreadsheet generating code


<a name="removals">Removing items or collections (takedown requests)</a> 
--------------------------

Removing collections involves deleting records from CouchDB stage and production environments, as well as Solr stage and production environments; and then updating the Elastic Beanstalk.

In addition to removing the item from Calisphere, notify DPLA to remove the item from there.

#### <a name="removalitem">Individual items</a>

* Follow this process: [Editing or deleting individual items](#editnforgetit)
-or-
* Create a list of the CouchDB identifiers for the items, and add them to a file (one per line). Then run `delete_couchdb_id_list.py` with the file as input:`delete_couchdb_id_list.py <file with list of ids>`
* From the Collection Registry, select `Queue sync from from CouchDB stage to Solr stage` and `Queue sync from CouchDB production to Solr production`
* Update Elastic Beanstalk with the updated Solr index


#### <a name="removalcollection">Entire collection</a>

* From the Collection Registry, select `Queue deletion of documents from CouchDB stage`, `Queue deletion of documents from Solr stage`, `Queue deletion of documents from CouchDB production`, and `Queue deletion of documents from Solr production`
* Update the Collection Registry entry, setting "Ready to publish" to "None" -- and change the harvesting endpoint to "None"
* Update Elastic Beanstalk with the updated Solr index

If you need more control of the process (i.e. to put on a different queue),
you can use the following command syntaxes on the dsc-blackstar role account:

`./bin/delete_couchdb_collection.py adrian.turner@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/26275`
`./bin/queue_delete_solr_collection.py adrian.turner@ucop.edu high-stage 26275`



<a name="restores">Restoring collections from production</a>
--------------------------

We've had a couple of cases where the pre-prodution index has had a
collection deleted for re-harvesting but the re-harvest has not been
successful and we want to publish a new image.
This script will take the documents from one solr index and push them to
another solr index.
This script can be run from the hrv-stg or hrv-prd account. For each, the source documents come from solr.calisphere.org which drives Calisphere. Depending on which role account you are in, it will either update the "stage" or the pre-production solr.

* Log onto the appropriate role account (hrv-stg or hrv-prd).  That will set the context for the *originating* solr index, from which you want to push data.
* run `URL_SOLR=$URL_SOLR/dc-collection sync_solr_documents.py <collection id>` to push the data to the target solr index.



<a name="addtl">Additional resources</a> 
--------------------------

### <a name="longprocess">Running long processes</a>

The `snsatnow` wrapper script may be used to run *any* long running process. It will background and detach the process so you can log out. When the process finishes or fails, a message will be sent to the dsc_harvesting_repot Slack channel.

To use the script, just add it to your script invocation
```shell
snsatnow <cmd> --<options> <arg1> <arg2>....
```
NOTE: if your command has arguments that are surrounded by quotes (") you'll need to escape those by putting a backslash (\) in front of them.


### <a name="newcode">Picking up new harvester or ingest code</a>

When new harvester or ingest code is pushed, you need to create a new AMI to pick up the new code:

* First, terminate the existing machines: `ansible-playbook -i ~/code/ec2.py ~/code/ingest_deploy/ansible/terminate_workers.yml <--limit=10.60.?.?>`
* Then follow steps/contact harvest programmer to follow steps in "create a new AMI", below

### <a name="solrscratch">Recreating the Solr Index from scratch</a>

The solr index is run in a docker container. To make changes to the schema or
other configurations, you need to recreate the docker image for the container.

NOTE: THIS NEEDS UPDATING
To do so in the ingest environment, run `ansible-playbook -i hosts solr_docker_rebuild.yml`.  This will remove the docker container & image, rebuild the image, remove the index files and run a new container based on the latest solr config in https://github.com/ucldc/solr_api/.

You will then have to run `/usr/local/solr-update.sh --since=0` to reindex the
whole couchdb database.

See 'Harvest Dockers' notes for more details on Docker usage/configuration: https://docs.google.com/document/d/1TYaKQtg-FNfoIUmYykqfml6fKn3gthRTb2cv_Tyuclc/edit#

### <a name="cdbsearch">How to find a CouchDB source document for an item in Calisphere</a>

#### See the new tool for automating this here: https://github.com/mredar/ucldc_api_data_quality/blob/master/reporting/README.md

Tracing back to the document source in CouchDB is critical to diagnose problems with data and images.

Get the Solr id for the item. This is the part of the URL after the /item/ without the final slash. For https://calisphere.org/item/32e2220c1e918cf17f0597d181fa7e3e/, the Solr ID is 32e2220c1e918cf17f0597d181fa7e3e.

Now go to the Solr index of interest and query for the id:
https://harvest-stg.cdlib.org/solr/dc-collection/select?q=32e2220c1e918cf17f0597d181fa7e3e&wt=json&indent=true

Find the `harvest_id_s` value, in this case "26094--LAPL00050887". Then plug this into CouchDB for the ucldc database:
https://harvest-stg.cdlib.org/couchdb/ucldc/26094--LAPL00050887 (or with the UI - https://harvest-stg.cdlib.org/couchdb/_utils/document.html?ucldc/26094--LAPL00050887)

### <a name="editnforgetit">Editing or deleting individual items</a>

It may be handy to edit an individual object, in cases where key information in the source metadata -- such as a date -- was entered in error, and is throwing off the Solr date facet. In these cases, you should notify the contributor to update the source metadata, and re-harvest. In parallel (and so not to hold up publication of the collection), you can selectively edit the object in CouchDB:

1. Locate the CouchDB ID for the object that needs editing (look it up in Solr).
2. Log on to blackstar and run `sudo su - hrv-stg` and then `echo "$COUCHDB_PASSWORD"` to obtain the password for the `harvester` account.
3. Access the CouchDB stage UI.
4. On the bottom right corner, click on Login.
5. Enter `harvester` as the Username and copy in the password obtained in step #2.
6. Retrieve the record and double click the field in the sourceResource section to edit the value (e.g., the incorrect date).
7. Click on the green check mark to the right of the edit box.
8. Click on Save Document on the upper left hand corner.
9. Delete collection from Solr stage.
10. Delete collection from Solr prod.
11. Re-synch collection from CouchdB stage to Solr stage.
12. Re-synch collection from CouchDB stage to CouchDB prod.
13. Re-synch collection from CouchDB prod to Solr prod.

This also applies to cases where a contributor removes an object from their source collection. In lieu of reharvesting the entire collection, you can selectively delete an item from CouchDB (then synch from CouchDB to Solr).

### <a name="batchediting">Batch replacing CouchDB field values by collection</a>

For relatively simple find-and-replace tasks across an entire CouchDB collection, where a full re-harvest is too time-consuming/cumbersome, use this script. **NOTE:** Use carefully, as this will alter the CouchDB records for an entire collection, with the only way to 'restore' being a full re-harvest. **ALSO**, this script will replace whatever is in the given [fieldName] with the given "newValue" (unless you add a "--substring" value, below). It does NOT yet add/append a new value on to existing values--therefore not suitable for editing fields with multiple values.

* Log onto blackstar & sudo su - hrv-stg
* Run `python ~/bin/queue_batch_update_couchdb.py <email> normal-stage <collection ID> <fieldName> <newValue> optional:(--substring XXXX)`
    * <email> EX: mmckinle@ucop.edu
    * <collection ID> EX: 26957
    * <fieldName> The field containing value that needs replacing. Use / to delimit nested fields EX: sourceResource/stateLocatedIn/name
    * <newValue> New value to add to field. If multiple words, surround with quotes EX: "UCSF Medical Center at Mount Zion Archives"
    * Optional: --substring XXXX Used to specify a particular value or substring WITHIN the entire metadata value to replace. if using, insert substring switch followed by value XXXX to find/replace. 

### <a name="highstage">Creating/Harvesting with High Stage Workers</a>

Sometimes you may need to create one or more "High Stage" workers, for example if the normal stage worker queue is very full and you need to run a harvest job without waiting for the queue to empty. The process is performed from the `hrv-stg` command line as follows.

**Creating high stage workers:**
* Log onto blackstar and run `sudo su - hrv-stg`
* Create one or more worker machines just as you would in the "developer" (see below) process: `snsatnow ansible-playbook ~/code/ansible/create_worker.yml --extra-vars=\"count=1\"` .
* After workers are created, run `get_worker_info.sh` and compare results to currently provisioned/running "normal" workers RQ dashboard to determine the IP addresses of new workers. 
* Provision with `--extra-vars="rq_work_queues=['high-stage']"` switch to make new workers high stage workers. Also use `--limit` switch with IP addresses of new workers from step above to only provision new workers. Do NOT re-provision running workers! Full example command: `snsatnow ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml --limit=10.60.29.* --extra-vars="rq_work_queues=['high-stage']"`

**Running jobs on high stage workers:**
* From `hrv-stg` command line, run the following command to queue a high-stage harvest, providing your `EMAIL` address and collection # to harvest for `XXXXX` where appropriate: `./bin/queue_harvest.py EMAIL@ucop.edu high-stage https://registry.cdlib.org/api/v1/collection/XXXXX/`
* To queue an image harvest or solr sync, replace the first part of the command above with `./bin/queue_image_harvest.py` or `./bin/queue_sync_to_solr.py`, respectively
* More commands can be found in the bin folder by running `ls ./bin` from command line. Most are self-explanatory from the script titles. Again, just replace the first part of the full command above with `./bin/other-script-here.py` as needed
* When finished harvesting, terminate the high-stage workers as you would any other. EX: `ansible-playbook -i ~/code/ec2.py ~/code/ansible/terminate_workers.yml <--limit=10.60.?.?>`

### <a name="redirects">Generating Redirects when Record Page URLs change</a>

When an Institution migrates to a new repository system, or if the record page URL for an object already in Calisphere changes for any other reason, this will change the Calisphere URL for that object--since the IDs used to build Calisphere URLs are based off the repository/local record page URL. We need to do our best to match and redirect from the 'old' Calisphere URL to the 'new', so that someone following the 'old' Calisphere URL link won't get a 404 by default.

<b>IMPORTANT:</b>So that you don't accidentally delete the 'old' URL IDs, ONLY run this AFTER collection is synced, QA’ed and approved on SOLR TEST but BEFORE syncing to SOLR PROD

<b>Matching Tips</b>
* SOLR has trouble matching values from fields with multiple values, such as `dc.identifier`. If possible, it's best to remove all values from the field OTHER than the one you want to match on. `sed` commands help with this:
    * To remove a <i>substring</i> from a particular value for a more accurate match (i.e. removing `.libraries` from `clarement.libraries.org/...`), use `s/[value]//g` like so: `sed -i 's/.libraries//g' prod-URLs-26569.json`
    * To remove an <i>entire line</i> from a file (i.e. removing values beginning with `cavpp` from every multi-value identifier field), use `//d` like so: `sed -i '/cavpp/d' prod-URLs-26569.json`
* For some reason (especially in cases like the one above), the Redirect Process will sometimes match all records to a single other record in the collection incorrectly. This seems to be solved by using the `--exact_match` switch (see step 4 below)

In `hrv-prd` role account:
1. Compare a few "old" and "new" version of records between SOLR/Couch PROD and SOLR/Couch TEST to determine match field to best match records between SOLR PROD and SOLR TEST--ideally an object-unique and unchanging value between records sets on PROD and TEST such as `identifier`
2. Run `external-redirect-get-solr_prod-id.py [Collection ID] [match field]` , with appropriate [Collection ID] and pre-determined [match field], which will generate a JSON [output file] with the “old” harvest IDs from SOLR PROD and corresponding [match field] value
3. Make any edits necessary to JSON [output file] to better match [match field] value between SOLR PROD and SOLR TEST
4. Run `external-redirect-generate-URL-redirect-map.py [output file]` , with [output file] from external-redirect-get-solr_prod-id.py as input. This will use [match field] value to generate a list of “old” harvest IDs from SOLR PROD paired with corresponding “new” harvest IDs from SOLR TEST. This list will then be appended to the master CSPHERE_IDS.txt redirect file. NOTE: If you know the match field you are using may have multiple matches (i.e. using `title` field when some records have identical titles), add the `--exact_match` switch at the end, which will change the SOLR query which normally employs wildcards for approximate searching, to an exact match. If more than one SOLR records are found when an `--exact_match` switch is used, the original record will redirect to a SOLR search query for that match value within the Calisphere UI--not ideal but better than having SOLR just pick the same record over and over for an exact-value-match redirect.
5. The script in above step will automatically create a CSPHERE_IDS_BACKUP[date].txt file each time it is run. 
6. When finished with a particular institution, move the [output files] to the `redirectQueries` directory
7. Sync collection/s to Couch/SOLR Prod
8. To ensure redirects are not deployed prematurely, only run the following script to copy CSPHERE_IDS.txt to S3 24 HOURS OR LESS before building a new index: `aws s3 cp /home/hrv-prd/CSPHERE_IDS.txt s3://static-ucldc-cdlib-org/redirects/` Work with Calisphere UI programmer to make sure new redirects are deployed as soon as new index containing new URLS goes live

<a name="commonfixes">Fixes for Common Problems</a>
-------------------------

### <a name="failures">What to do when harvests fail</a>

First take a look at the RQ Dashboard. There will be a bit of the error message
there. Hopefully this would identify the error and you can modify whatever is
going wrong.


#### Common worker error messages

* Worker forcibly terminated, while job was in-progress: `ShutDownImminentException('shut down imminent (signal: %s)' % signal_name(signum), info) ShutDownImminentException: shut down imminent (signal: SIGALRM)`
* (More forthcoming...)

#### Checking the logs

If you need more extensive access to logs, they are all stored on the AWS
CloudWatch platform. 
The /var/local/rqworker & /var/local/akara contain the logs from the worker
processes & the Akara server on a worker instance.
The logs are named with the instance id & ip address, e.g. ingest-stage-i-127546c9-10.60.28.224

From the blackstar machine you can access the logs on CloudWatch using the scripts in the bin directory

First, get the IPs of the worker machines by running `get_worker_info.sh`

Then for the worker whose logs you want to examine:
`get_log_events_for_rqworker.sh <worker ip>`

This is an output of the rqworker log, for the akara log use:
`get_log_events_for_akara.sh <worker ip>`

If you need to go back further in the log history, for now ask Mark.

If this doesn't get you enough information, you can ssh to a worker instance and
watch the logs real time if you like. tail -f /var/local/rqworker/worker.log or
/var/local/akara/logs/error.log.

#### pull down on registry does not schedule jobs

Sometimes the actions pull down on the collection model becomes disconnected from `rq`. 

Restarting the `stunnel` on both ends often fixes this.

on `registry`
```sh
ssh registry.cdlib.org
sudo su - registry
monit restart stunnel
```

on `blackstar`
```sh
sudo su - hrv-prd
ssh front
sudo /etc/init.d/stunnel restart
```


### <a name="imagefix">Image problems</a>

#### Verify if and what files were harvested, for a given object 

Use the following script in the `ucldc_api_data_quality/reporting directory` (following the steps at https://github.com/mredar/ucldc_api_data_quality/tree/master/reporting) to generate a report for the object. The <ID> value is the *id* for the object, as reflected in Solr or CouchDB (e.g., 6d445613-63d3-4144-a530-718900676db9):

`python get_couchdata_for_calisphere_id.py <ID>`

Example report result:

```
===========================================================================
Calisphere/Solr ID: 6d445613-63d3-4144-a530-718900676db9
CouchDB ID: 26883--6d445613-63d3-4144-a530-718900676db9
isShownAt: https://calisphere.org/item/6d445613-63d3-4144-a530-718900676db9
isShownBy: https://nuxeo.cdlib.org/Nuxeo/nxpicsfile/default/6d445613-63d3-4144-a530-718900676db9/Medium:content/
object: ce843950f622d303b83256add5b19d34
preview: https://calisphere.org/clip/500x500/ce843950f622d303b83256add5b19d34
===========================================================================
```

The URL in `isShownBy` reflects the endpoint to an file, which is used by the harvesting code ("Queue image harvest to CouchDB stage" action) to derive a small preview image (used for the object landing page); that preview image is also used for thumbnails in search/browse and related item results.  Note that you can also verify `isShownBy` by [looking up the object in CouchDB](#cdbsearch).

The URL in `preview` points to the resulting preview image.


#### No preview image, or thumbnail in search/browse results? (Nuxeo and non-Nuxeo sources)

Double-check the URL in the `preview` field. If there's no functional URL in `preview` (value indicates "None"), then a file was not successfully harvested. To fix: 

* Try re-running the [process to harvest preview and thumbnail images](#harvestpreview) image
* Check again to see if the URL now shows up in the `preview` field. If so, sync from CouchDB stage to Solr stage

For Nuxeo-based objects, the following logic is baked into the process for harvesting preview and thumbnail images:
1. If object has an image at the parent level, use that. Otherwise, if component(s) have images, use the first one we can find
2. If an object has a PDF or video at parent level, use the image stashed on S3
3. Otherwise, return "None"


#### No access files, preview image (for PDF or video objects), or complex object component thumbnails? (Nuxeo only)

The `media.json` output created through the ["deep harvest"](#deepharvest) process references URL links back to the source files in Nuxeo.  If there's no `media.json` file -- or if the media.json has broken or missing URLs -- then the files could not be successfully harvested. To fix:

* Try re-running the [deep harvest for a single object](#deepharvest) to regenerate the media.json and files.
* Check the media.json again, to confirm that it was generated and/or its URLs resolve to files. If AOK, sync from CouchDB stage to Solr stage

#### Persistent older versions of access files, preview image (for PDF or video objects), or complex object component thumbnails? (Nuxeo only)

If older versions of the files don't clear out after re-running a deep harvest, you can manually queue the image harvest to force it to re-fetch images from Nuxeo. First, you need to clear the "CouchDB ID -> image url" cache and then set the image harvest to run with the flag --get_if_object (so get the image even if the "object" field exists in the CouchDB document)

* Log onto blackstar & sudo su - hrv-stg
* Run `python ~/bin/redis_delete_harvested_images_script.py <collection_id>`. This will produce a file called `delete_image_cache-<collection_id>` in the current directory.
* Run `redis.sh < delete_image_cache-<collection_id>`. This will clear the cache of previously harvested URLs.
* Run `python ~/bin/queue_image_harvest.py mredar@gmail.com normal-stage https://registry.cdlib.org/api/v1/collection/<collection_id>/ --get_if_object`

#### Removing multiple objects from collection with the same generic placeholder image file

Sometimes a collection will be harvested with multiple metadata-only records with an associated 'placeholder' file, but nothing within the metadata denoting the record's metadata-only status. In these cases, the only way to identify and remove these metadata-only records is by determining the placeholder file's 'Object' value in CouchDB. This script will find and remove such records given the Collection ID and the associated 'bogus' Object value from CouchDB.

Note that this will only work if every metadata-only record has the exact same placeholder image, as only an identical file will generate the same 'Object' value in CouchDB.

* Delete collection from SOLR stage
* Get 'Object' value from one of the metadata-only CouchDB records you wish to remove
* Log onto blackstar & sudo su - hrv-stg
* Run `delete_couchdocs_by_obj_checksum.py [Collection ID] [Bogus Object value]`
* Script will return number of matching records found and ask for confirmation before deleting. Type `yes` and script will delete records from CouchDB
* Re-sync collection from CouchDB stage to SOLR stage

#### Akara Log reporting "Not an Image" for collection object(s), even though you are certain the object file(s) are image(s)?

By default, the image harvester checks the value of `content-type` within the HTML headers of the isShownBy URL when retrieving preview images, and if the content-type is not some type of image or is missing, the object is skipped and no image is harvested. However, sometimes the content-type value is missing or erroneous when the file is clearly an image that can be harvested. If you're sure the files are indeed images, run image harvest with the `--ignore_content_type` to bypass the content-type check and grab the image file anyway.

* Log onto blackstar & sudo su - hrv-stg
* Run `python ~/bin/queue_image_harvest.py <your email> normal-stage https://registry.cdlib.org/api/v1/collection/<collection_id>/ --ignore_content_type`

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

### Addendum: Building new worker images - For Developers


* Log onto blackstar and run `sudo su - hrv-stg`
* To start some worker machines (bare ec2 spot instances), run: `snsatnow ansible-playbook ~/code/ansible/create_worker.yml --extra-vars=\"count=1\"` . 
  * For on-demand instances, run: `snsatnow ansible-playbook ~/code/ansible/create_worker_ondemand.yml --extra-vars=\"count=1\"`
  * For an extra large (and costly!) on-demand instance (e.g., m4.2xlarge, m4.4xlarge), run: `ansible-playbook ~/code/ansible/create_worker_ondemand.yml --extra-vars="worker_instance_type=m4.2xlarge"` .  *If you create an extra large instance, make sure you terminate it after the harvesting job is completed!*

The `count=##` parameter will set the number of instances to create. For harvesting one small collection you can set this to `count=1`. To re-harvest all collections, you can set this to `count=20`. For anything in between, use your judgment.

With the `snsatnow` wrapper, the results will be messaged to the dsc_harvesting_report Slack channel when the instances are created.

The default instance creation will attempt to get instances from the "spot" market so that it is cheaper to run the workers. Sometimes the spot market price can get very high and the spot instances won't work. You can check the pricing by issuing the following command on blackstar, hrv-stg user:

```sh
aws ec2 describe-spot-price-history --instance-types m3.large --availability-zone us-west-2c --product-description "Linux/UNIX (Amazon VPC)" --max-items 2
```

Our spot bid price is set to .133 which is the current (20160803) on demand price. If the history of spot prices is greater than that or if you see large fluctuations in the pricing, you can request an on-demand instance instead by running the ondemand playbook : (NOTE: the backslash \ is required)

```sh
snsatnow ansible-playbook ~/code/ansible/create_worker_ondemand.yml --extra-vars=\"count=3\"
```

#### <a name="harvestprovisionstg">Provision stage workers to act on harvesting jobs</a>

*If you restarted a stopped instance, you don't need to do the steps below*

Once this is done and the stage worker instances are in a state of "running", you'll need to provision the workers by installing required software, configurations and start running Akara and the worker processes that listen on the queues specified:

* Log onto blackstar and run `sudo su - hrv-stg`
* To provision the workers, run: `snsatnow ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml`
* Wait for the provisioning to finish; this can take a while, 5-10 minutes is not
unusual. If the provisioning process stalls, use `ctrl-C` to end the process then re-do the ansible command.
* Check the status of the the harvesting process through the <a href="https://harvest-stg.cdlib.org/rq/">RQ Dashboard</a>.  You should now see the provisioned workers listed, and acting on the jobs in the queue. You will be able to see the workers running jobs (indicated by a "play" triangle icon) and then finishing (indicated by a "pause" icon).

#### Limiting provisioning by IP
If you already have provisioned worker machines running jobs, use the
`--limit=<ip range>` eg. --limit=10.60.22.\* or `--limit=<ip>,<ip>` eg. --limit=10.60.29.109,10.60.18.34 to limit the provisioning to the IPs of the newly-provisioned machines (and so you don't reprovision 
a currently running machine). Otherwise rerunning the provisioning will put the 
current running workers in a bad state, and you will then have to log on to the 
worker and restart the worker process or terminate the machine.  Example of full command: `snsatnow ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml --limit=10.60.29.*`

AWS assigns unique subnets to the groups of workers you start, so in general,
different generations of machines will be distinguished by the different C class
subnet. This makes the --limit parameter quite useful.

#### Provisioning workers to specific queues

By default, stage workers will be provisioned to a "normal-stage" queue. To provision them to a different queue -- e.g., "high-stage", use the following command with the --extra-vars parameter:

`ansible-playbook -i ~/code/ec2.py ~/code/ansible/provision_worker.yml --limit=10.60.22.123 --extra-vars="rq_work_queues=['high-stage']"`

### Creating new worker AMI

#### Creating new AMI/Updating Image ID

Once you have a new worker up and running with the new code, you need to create an image from it.

[NOTE: Now handled automatically by create_worker_ami] First SSH to the worker, run security updates and restart:
* `yum update --security -y`
* `/usr/local/bin/stop-rqworker.sh`
* `/usr/local/bin/start-rqworker.sh`

[NOTE: Now handled automatically by create_worker_ami] Then run `crontab -e` on the worker, remove the nightly security update cronjob in the crontab, and save.

Then back on `hrv-stg`:

```bash
ansible-playbook -i hosts ~/code/ansible/create_worker_ami.yml --extra-vars="instance_id=<running worker instance id>"
```

You can get the instance_id by running `get_worker_info.sh`.

This will produce a new image named <env>_worker_YYYYMMDD. Note the image id that is returned by this command.

You now need to update the image id for the environment. Edit the file ~/code/ansible/group_vars/<env> (either stage or prod). Change the worker_ami value to the new image id e.g:

```
worker_ami: ami-XXXXXX
```


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

