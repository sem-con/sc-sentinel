# <img src="https://github.com/sem-con/sc-sentinel/raw/master/assets/images/oyd_blue.png" width="60"> EODC Satellite Data    
These [Semantic Containers](https://www.ownyourdata.eu/semcon) demonstrate a processing pipeline by accesing satellite data from [EODC](https://eodc.eu), performing atmospheric correction and finally clipping to an area of 10x10 km.    

Docker Images:    
* download data: https://hub.docker.com/r/semcon/sc-sentinel_read    
* atmospheric correction: https://hub.docker.com/r/semcon/sc-sen2cor
* clip image: https://hub.docker.com/r/semcon/sc-sentinel_read    

## Usage   
To get a general introduction for using Semantic Containers please refer to the [SemCon Tutorial](https://github.com/sem-con/Tutorials).    
Start containers locally:    
```
$ docker pull semcon/sc-sentinel_read
$ docker pull semcon/sc-sen2cor
$ docker pull semcon/sc-sentinel_clip

$ svn export --force https://github.com/sem-con/sc-sentinel/trunk/config/ .
$ docker run -p 4000:3000 -d --name sentinel_read \
      -v /path/to/local/directory/sc-sentinel:/data \ 
      semcon/sc-sentinel_read \
      /bin/init.sh "$(< init_read.trig)"
$ docker run -p 4001:3000 -d --name sen2cor \
      -v /path/to/local/directory/sc-sentinel:/data \
      semcon/sc-sen2cor \
      /bin/init.sh "$(< init_sen2cor.trig)"
$ docker run -p 4002:3000 -d --name sentinel_clip \
      -v /path/to/local/directory/sc-sentinel:/data \
      semcon/sc-sentinel_clip \
      /bin/init.sh "$(< init_clip.trig)"
```    

### Download Data    
The first step is to download the raw data as made available from the Sentinel-2 satellites. Trigger a download through the following options:    
* `lat`: point of interest lattitude (e.g., 47.61)    
* `long`: point of interest longitude (e.g., 13.78)    
* `start`: begin date of chosen time frame (e.g., 2019-05-01)    
* `end`: end date of chosen time frame (e.g., 2019-05-10)    
* `filter`: regular expression that the download file must match; leave empty to omit the filter (e.g., UW); for each date there are 2 files available and this options allows to ommit one type    

Example local request:    
```
$ curl -s "http://localhost:4000/api/data/plain?lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=UW" | jq
[
  {
    "rid": "83d2b9ea-a684-4544-8ae2-1db90f74c227",
    "status": 0,
    "message": "request created",
    "request": "lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=TVN"
  }
]
```   
_Note:_ Since such a request is long running tasks, Semantic Containers perform asynchronous processing. The immediate response is therefore a Response-ID (rid) and it is possible to retrieve the status of such a request by querying the container with this Response-ID:    
```
$ curl -s "http://localhost:4000/api/data/plain?rid=83d2b9ea-a684-4544-8ae2-1db90f74c227" | jq
[
  {
    "rid": "83d2b9ea-a684-4544-8ae2-1db90f74c227",
    "status": 1,
    "message": "request in progress",
    "request": "lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=TVN",
    "file-list": [
      "S2A_MSIL1C_20190501T100031_N0207_R122_T33TVN_20190501T110719.zip",
      "S2A_MSIL1C_20190504T101031_N0207_R022_T33TVN_20190504T122526.zip"
    ]
  }
]
```   

Example request for this Semantic Container hosted by ZAMG:    
```
$ curl -s "https://vownyourdata.zamg.ac.at:9700/api/data/plain?lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=TVN" | jq
```    

With the following command a single file can be downloaded from a remote Semantic Container:    
```
$ wget https://vownyourdata.zamg.ac.at:9700/api/download/S2A_MSIL1C_20190501T100031_N0207_R122_T33TVN_20190501T110719.zip
```    

### Perform Atmospheric Correction    
Next the available downloaded data can be processed by the [sen2cor utility](http://step.esa.int/main/toolboxes/sentinel-2-toolbox/) provided by the [European Space Agency](https://www.esa.int/ESA) (ESA). As input available files from the `sentinel_read` container are provided by using the following option:    
* `file`: a filter (regular expression) to select the list of available files (e.g., 201905)    
Additionally, for the processing `sen2cor` container the target resolution must be specified:    
* `resolution`: one of the following 3 resolutions are available - 60m, 20m, 10m    

Example local request:   
```
$ curl -s "http://localhost:400/api/data?file=20190504" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "http://localhost:4001/api/data?resolution=60" | jq
```   
Example request for this Semantic Container hosted by ZAMG:    
```
$ curl -s "https://vownyourdata.zamg.ac.at:9700/api/data?file=20190504" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "https://vownyourdata.zamg.ac.at:9701/api/data?resolution=60" | jq
```    
With the following command a single file can be downloaded locally from a remote Semantic Container:    
```
$ wget https://vownyourdata.zamg.ac.at:9701/api/download/T33TVN_20190504T101031_TCI_60m.jp2
```    

### Clip Image    
And finally the processed image can be cropped to a 10x10 km segment. As input available files from the `sen2cor` container are provided by using the following option:    
* `file`: a filter (regular expression) to select the list of available files (e.g., 201905)    
Additionally, for the processing `sentinel_clip` container the following options must be specified:    
* `lat`: point of interest lattitude (e.g., 47.61)    
* `long`: point of interest longitude (e.g., 13.78)    

Example local request:   
```
$ curl -s "http://localhost:4001/api/data?file=201905" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "http://localhost:4002/api/data?lat=47.61&long=13.78" | jq
```   
Example request for this Semantic Container hosted by ZAMG:    
```
$ curl -s "https://vownyourdata.zamg.ac.at:9701/api/data?file=201905" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "https://vownyourdata.zamg.ac.at:9702/api/data?lat=47.61&long=13.78" | jq
```    
With the following command a single file can be downloaded locally from a remote Semantic Container:    
```
$ wget https://vownyourdata.zamg.ac.at:9702/api/download/T33UWP_20190501T100031_TCI_60m.png
```    

## Examples    
This section shows examples on using this Semantic Container processing pipeline.    

### Images    
The Sentinel Semantic Container processing pipeline was used to generate a time-laps video of Bad Aussee ([the center of Austria](https://de.wikipedia.org/wiki/Mittelpunkt_%C3%96sterreichs)) and is available on YouTube: https://youtu.be/N5fz6TRem1w    
<img src="https://github.com/sem-con/sc-sentinel/raw/master/sample/T33TVN_20180906T101021_TCI_10m.png" height="250" alt="Bad Aussee Satellite Image">    
The source high resolution images are [available here](https://github.com/sem-con/sc-sentinel/tree/master/sample).

### Provenance Chain    
Semantic Container automatically generate a provenance chain along the process pipeline when an image is created from the Sentinel source data, processed by the Sentinel-2 toolbox, and finally clipped to the relevant area. The following command generates the provenance information based on the [PROV Ontology](https://www.w3.org/TR/prov-o/):
```
$ curl -s "https://vownyourdata.zamg.ac.at:9702/api/data?file=201905" | \ 
      jq '.provision.provenance' | ruby -e "puts $(</dev/stdin)"
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix void: <http://rdfs.org/ns/void#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix sc: <http://w3id.org/semcon/ns/ontology#> .
@prefix scr: <http://w3id.org/semcon/resource/> .

scr:data_c276b22776c4_ffd27e87 a prov:Entity;
    sc:dataHash "c276b22776c4c68880840a07f828a977be6cdc735626b5325ae91d5b58c9da79"^^xsd:string;
    rdfs:label "data set from 2019-05-28T17:26:14Z"^^xsd:string;
    prov:wasAttributedTo scr:container_ffd27e87-d03e;
    prov:generatedAtTime "2019-05-28T17:26:14Z"^^xsd:dateTime;
.

scr:container_ffd27e87-d03e a prov:softwareAgent;
    sc:containerInstanceId "ffd27e87-d03e-4e19-9e7b-265c040e7c05"^^xsd:string;
    rdfs:label "Satellite Image Clipping"^^xsd:string;
    rdfs:comment "This container crops a satellite image."^^xsd:string;
    prov:actedOnBehalfOf scr:operator_a130a813440e;
.

scr:operator_a130a813440e a foaf:Person, prov:Person;
    sc:operatorHash "a130a813440e6fc01bd174e333ac2ade366372cbd09f6d460ac96c5d1eccf641"^^xsd:string;
    foaf:name "Christoph Fabianek";
    foaf:mbox <mailto:christoph@ownyourdata.eu>;
.

scr:input_fadb1e65aaa0 a prov:Activity;
    sc:inputHash "fadb1e65aaa0617f43bcd1db3bb761fc2daa4c8e4c20a21416de288e77bf770f"^^xsd:string;
    prov:used scr:data_9a83b5242ba6_85299065;
    prov:startedAtTime "2019-05-28T17:24:11Z"^^xsd:dateTime;
    prov:generated scr:data_c276b22776c4_ffd27e87;
.

scr:data_9a83b5242ba6_85299065 a prov:Entity;
    sc:dataHash "9a83b5242ba6ae988cf1c14380824d11350cc8809191935539f6fbf51c830237"^^xsd:string;
    rdfs:label "data set from 2019-05-28T17:24:10Z"^^xsd:string;
    prov:wasAttributedTo scr:container_85299065-414b;
    prov:generatedAtTime "2019-05-28T17:24:10Z"^^xsd:dateTime;
.

scr:container_85299065-414b a prov:softwareAgent;
    sc:containerInstanceId "85299065-414b-4d5e-974b-e2043f3ab1b4"^^xsd:string;
    rdfs:label "Sentinel Atmospheric Corrections"^^xsd:string;
    rdfs:comment "This container performs atmospheric corrections for Sentinel data."^^xsd:string;
    prov:actedOnBehalfOf scr:operator_a130a813440e;
.

scr:input_76505e3b5be8 a prov:Activity;
    sc:inputHash "76505e3b5be804ce4d3c8defba5597eaedd83ec14f4f480c34656d803bd3e3bd"^^xsd:string;
    prov:used scr:data_e2407dfa3192_41f80b87;
    prov:startedAtTime "2019-05-28T16:10:35Z"^^xsd:dateTime;
    prov:generated scr:data_9a83b5242ba6_85299065;
.

scr:data_e2407dfa3192_41f80b87 a prov:Entity;
    sc:dataHash "e2407dfa3192b05f2add4ee2aa1b127f2f24916370298946b159298770ddc3f6"^^xsd:string;
    rdfs:label "data set from 2019-05-28T16:10:33Z"^^xsd:string;
    prov:wasAttributedTo scr:container_41f80b87-9b8d;
    prov:generatedAtTime "2019-05-28T16:10:33Z"^^xsd:dateTime;
.

scr:container_41f80b87-9b8d a prov:softwareAgent;
    sc:containerInstanceId "41f80b87-9b8d-43d6-ba5e-aed6b837dbd6"^^xsd:string;
    rdfs:label "Sentinel Download"^^xsd:string;
    rdfs:comment "This container downloads Sentinel data from ftp://galaxy.eodc.eu"^^xsd:string;
    prov:actedOnBehalfOf scr:operator_a130a813440e;
.

scr:input_5b697319f458 a prov:Activity;
    sc:inputHash "5b697319f458166ac6d66ab5a151164ba357de42ce751d07ee9b17a08f9c838a"^^xsd:string;
    rdfs:label "input data from 2019-05-28T15:00:39Z"^^xsd:string;
    prov:startedAtTime "2019-05-28T15:00:37Z"^^xsd:dateTime;
    prov:endedAtTime "2019-05-28T15:00:39Z"^^xsd:dateTime;
    prov:generated scr:data_e2407dfa3192_41f80b87;
.
```    
The image below depicts this provenance information. Alternatively, the output can be visualized online with [PROV-O-Viz](http://provoviz.org/).
<img src="https://github.com/sem-con/sc-sentinel/raw/master/assets/images/provenance.png" width="60" alt="Provenance">


## Improve these Semantic Containers    

Please report any bugs or feature requests in the [GitHub Issue-Tracker](https://github.com/sem-con/sc-sentinel/issues) and follow the [Contributor Guidelines](https://github.com/twbs/ratchet/blob/master/CONTRIBUTING.md).

If you want to develop yourself, follow these steps:

1. Fork it!
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Send a pull request

&nbsp;    

## Lizenz

[MIT Lizenz 2019 - OwnYourData.eu](https://raw.githubusercontent.com/sem-con/sc-sentinel/master/LICENSE)

