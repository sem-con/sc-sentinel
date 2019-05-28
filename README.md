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
$ curl -s "http://localhost:400/api/data?file=201905" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "http://localhost:4001/api/data?resolution=60" | jq
```   
Example request for this Semantic Container hosted by ZAMG:    
```
$ curl -s "https://vownyourdata.zamg.ac.at:9700/api/data?file=201905" | \ 
    curl -s -H "Content-Type: application/json" -d @- \
    -X POST "https://vownyourdata.zamg.ac.at:9701/api/data?resolution=60" | jq
```    
With the following command a single file can be downloaded locally from a remote Semantic Container:    
```
$ wget https://vownyourdata.zamg.ac.at:9701/api/download/T33UXP_20180705T100031_TCI_60m.jp2
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
Semantic Container automatically generate a provenance chain along the process pipeline when an image is created from the Sentinel source data, processed by the Sentinel-2 toolbox, and finally clipped to the relevant area. The following command generates the provenance information using the [PROV Ontology](https://www.w3.org/TR/prov-o/):
```
$ curl -s "https://vownyourdata.zamg.ac.at:9702/api/data?file=201905" | \ 
      jq '.provision.provenance' | ruby -e "puts $(</dev/stdin)"
```    
The output above can be visualized online with [PROV-O-Viz](http://provoviz.org/).


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

