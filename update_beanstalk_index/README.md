# Building beanstalk for UCLDC Solr index

The Solr index that powers the Calisphere website is hosted on the AWS Elastic Beanstalk platform.

The CNAME `solr.calisphere.org` points to https://ucldc-solr.us-west-2.elasticbeanstalk.com, whichever Beanstalk environment which is at this address will be the server for our search requests.

The Beanstalk is hosted in the Oregon (us-west-2) AWS region. The application name is `ucldc-solr`. Currently it runs on only one micro EC2 instance.

The process to create a new production index is as follows:

1. Optimize the Solr index
2. Push the index to S3
3. Clone the existing environment
4. In the cloned environment, set the env var INDEX_PATH to the new index sub-path in S3
5. Rebuild the cloned environment
6. Check that the cloned environment is serving up the new index
7. Swap URLs from existing environment to the new cloned environment

This will put in place the new index.

Generally, I then rebuild the original environment and swap back so the name of the environment remains `ucldc-solr`. Not really necessary but makes it a bit easier to remember what's what.

## Step 1
Optimize the Solr index: 
* Go to the core admin page in Solr production:
https://harvest-prd.cdlib.org/solr/#/~cores/dc-collection
* Hit the `optimize` button. *This process will take a while*
* Keep refreshing until the index reports being optimized and current.

## Step 2
To push a new index to S3: 
* First run `/usr/local/bin/solr-index-to-s3.sh` on the production environment majorTom instance. *This process will take a while*. (It takes some time for the new index to be packaged and zipped on S3).
* Look at the log at `/var/local/solr-update/log/solr-index-to-s3-YYYYMMDD_HHMMSS.out` (e.g., `ls -lrth /var/local/solr-update/log/` to list all logs). Find the `s3_file_path` reports it will be something like: `"s3_file_path": "s3://solr.ucldc/indexes/production/2016/06/solr-index.2016-06-21-19_53_40.tar.bz2"`. 
* This is the value to pass into the update environment command

## Steps 3-5
The script `clone-with-new-s3-index.sh` will do steps 3 to 5 above.

* First, check what environments are running.  Run this from your home directory (e.g., /home/ec2-user):
```shell
eb list
```

* Now run the following, where the `<new index path>` is the value from Step #1 (e.g., 2016/06/solr-index.2016-06-21-19_53_40.tar.bz2). *This process will take a while*.  Again, by convention, we name the existing environment (`<old env name>`) `ucldc-solr`.  By convention, we have been naming the new environment (`<new env name>`) `ucldc-solr-1`.   
```shell
update_beanstalk_index/clone-with-new-s3-index.sh <old env name> <new env name> <new index path>
```

* When it finishes, you should be able to run the following, and see that INDEX_PATH is updated to the value passed to the script.
```shell
eb printenv <new env name>
```

## Step 6
Check the new environments URL for the proper search results:

* Run the following, to confirm the URL that is associated with the environment: 
```shell
cname_for_env.sh <new env name>
```

* You can check that the URL is up by running:
```shell
check_solr_api_for_env.sh <new env name>
```

## Step 7
Swap URLs from the existing environment to the new cloned environment running the updated solr index:

* First, check what environment has the ucldc-solr.us-west-2.elasticbeanstalk.com CNAME:
```shell
eb status <new env name>
```

Also, check the status and health of the environment.  Here's an example of a happy environment:
```
Environment details for: ucldc-solr
 Application name: ucldc-solr
 Region: us-west-2
 Deployed Version: new-nginx-index-html
 Environment ID: e-dmmzpvb2vj
 Platform: 64bit Amazon Linux 2016.03 v2.1.3 running Docker 1.11.1
 Tier: WebServer-Standard
 CNAME: ucldc-solr.us-west-2.elasticbeanstalk.com
 Updated: 2016-09-10 02:09:01.062000+00:00
 Status: Ready
 Health: Green
 ```

* If both look right, swap the URLs and the new index will be live (`eb swap -n <new env name> <old env name>`):

```shell
eb swap -n ucldc-solr-1 ucldc-solr
```


## Updating the `ucldc-solr` environment
I have been then updating the `ucdlc-solr` environment and then swapping the URL back, so that the environment we have up is always named `ucldc-solr`, but this is not required. The important thing is that the ucdlc-solr.us-west-2.elasticbeanstalk.com/solr/query URL works.
