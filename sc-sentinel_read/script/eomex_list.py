import sys
import os
import os.path as path
import requests
import json
import hashlib
import datetime
import argparse
import glob
from pt2rect import *

def download(startdate,enddate,bb):
	base_url = "https://eomex.eodc.eu/api?keywords=Sentinel-2A&tempextent_begin={}&tempextent_end={}&bbox={}"
	req = base_url.format(startdate, enddate, repr(bb))
	digest = hashlib.md5()
	digest.update(req)
	outfn = "{}.json".format(digest.hexdigest())
	has_cache = False
	try:
		if os.path.exists(outfn):
			with open(outfn,"rb") as fj:
				tj = json.loads(fj.read())
				has_cache = True
	except:
		pass
	if not has_cache:
		r = requests.get(req)
		if r.status_code == 200:
			tj = r.json()
			print(tj)
			tj["req"] = req
			with open(outfn,"wb") as fj:
				fj.write(json.dumps(tj,indent=2))
		else:
			tj = {"filelist":[],"matches":0,"nextrecord":0,"returned":0,"req":req}
	return tj

if __name__=="__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument('-begindate', type=str, help='date in YYYY-MM-DD format')
	parser.add_argument('-enddate', type=str, help='date in YYYY-MM-DD format')
	parser.add_argument('-bbox', type=float, nargs=4)
	parser.add_argument('-center', type=float, nargs=2, help="used in conjunction with radius, center location of bounding box")
	parser.add_argument('-radius', type=float, default=5., help="used in conjunction with center, radius in kilometers")
	parser.add_argument('-jsonconfig', type=str, help='filename of JSON file containing the selection')
	#parser.add_argument('-cloudcover', type=float, help='coverage percentage 0..94')
	parser.add_argument('-outdir', type=str, help='working directory where the image will be downloaded and processed')
	parser.add_argument('-skipifexist', default=False, action='store_true', help='skip already downloaded file(s)\nWARNING:broken download will not be checked')
	parser.add_argument('-debug', default=False, action='store_true', help='only print the action without actually downloading')

	args = parser.parse_args()
		
	jcfg = None
	if args.jsonconfig is not None:
		if args.jsonconfig.lower()=='stdin':
			jcfg = json.load(sys.stdin)
		elif os.path.exists(args.jsonconfig):
			with open(args.jsonconfig,'rb') as fj:
				jcfg = json.load(fj)
		
	if jcfg is not None:
		if 'begindate' in jcfg:
			args.begindate = jcfg['begindate']
		if 'enddate' in jcfg:
			args.enddate = jcfg['enddate']
		if 'bbox' in jcfg:
			args.bbox = jcfg['bbox']
		if 'center' in jcfg:
			args.bbox = jcfg['center']
		if 'outdir' in jcfg and jcfg['outdir'] is not None:
			args.outdir = jcfg['outdir']

	# download the file list
	if args.begindate is not None:
		begindate = datetime.datetime.strptime(args.begindate,"%Y-%m-%d")
	else:
		begindate = datetime.datetime(2018,6,1)

	if args.enddate is not None:
		enddate = datetime.datetime.strptime(args.enddate,"%Y-%m-%d")
	else:
		enddate = begindate + datetime.timedelta(days=1)

	if args.bbox is not None:
		bbox = args.bbox
	elif args.center is not None:
		bbox = list(get_bounding_rect(args.center[0], args.center[1], 5., get_datum_radius()*1e-3))
		args.bbox = bbox
	else:
		bbox = [48.117360,16.0845801,48.3233231,16.180650] #Vienna [lat, lng, lat, lng]

	if args.debug:
		print(args)
		exit(0)

	tj = download(begindate.strftime("%Y-%m-%d"),enddate.strftime("%Y-%m-%d"), bbox)
	json.dump(tj, sys.stdout)
