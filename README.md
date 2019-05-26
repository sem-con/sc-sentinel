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

$ docker run -p 4000:3000 -d --name sentinel_read \
      -v /home/user/tmp/sc-sentinel:/data \ 
      semcon/sc-sentinel_read \
      /bin/init.sh "$(< init_read.trig)"
$ docker run -p 4001:3000 -d --name sen2cor \
      -v /home/ownyourdata/tmp/sc-sentinel:/data \
      semcon/sc-sen2cor \
      /bin/init.sh "$(< init_sen2cor.trig)"
$ docker run -p 4002:3000 -d --name sentinel_clip \
      -v /home/ownyourdata/tmp/sc-sentinel:/data \
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
    "rid": "c9c0de4a-a311-4393-af71-49cccc768704",
    "status": 0,
    "message": "request created",
    "request": "lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=UW"
  }
]
```   
Example request for this Semantic Container hosted by ZAMG:    
```
$ curl -s "https://vownyourdata.zamg.ac.at:9700/api/data/plain?lat=47.61&long=13.78&start=2019-05-01&end=2019-05-10&filter=UW" | jq
```    

_Note:_ Since those requests are long running tasks, Semantic Containers perform asynchronous processing. The immediate response is therefore a Response-DI (rid) and it is possible to retrieve the status of such a request by querying the container with this Response-ID:    
```
$ curl -s "http://localhost:4000/api/data/plain?rid=c9c0de4a-a311-4393-af71-49cccc768704" | jq
```   


With the following command a single file can be downloaded locally from a remote Semantic Container:    
```
$ wget https://vownyourdata.zamg.ac.at:9700/api/download/S2A_MSIL1C_20190418T095031_N0207_R079_T33UXP_20190418T115043.zip
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

#### Provenance Chain    

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


