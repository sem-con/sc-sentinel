import sys
import os
import os.path as path
import json
import hashlib
import datetime
import argparse
import glob
from pt2rect import *

if __name__=="__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument('-bbox', type=float, nargs=4)
	parser.add_argument('-center', type=float, nargs=2, help="used in conjunction with radius, center location of bounding box")
	parser.add_argument('-radius', type=float, default=5., help="used in conjunction with center, radius in kilometers")

	parser.add_argument('-jsonconfig', type=str, help='filename of JSON file containing the selection')
	parser.add_argument('-infile', type=str, help='input true color Level2 image', required=True)
	parser.add_argument('-outdir', type=str, help='output directory where the mosaic should be written to', required=True)
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
		if 'bbox' in jcfg:
			args.bbox = jcfg['bbox']
		if 'center' in jcfg:
			args.center = jcfg['center']
		if 'radius' in jcfg:
			args.radius = jcfg['radius']
		if 'outdir' in jcfg and jcfg['outdir'] is not None:
			args.outdir = jcfg['outdir']
		if 'infile' in jcfg and jcfg['infile'] is not None:
			args.infile = jcfg['infile']

	if args.bbox is not None:
		bbox = args.bbox
	elif args.center is not None:
		bbox = list(get_bounding_rect(args.center[0], args.center[1], args.radius, get_datum_radius()*1e-3))
		args.bbox = bbox
	else:
		bbox = [48.117360,16.0845801,48.3233231,16.180650] #Vienna [lat, lng, lat, lng]

	if args.debug:
		print(args)
		exit(0)

	outdir = args.outdir

	if not os.path.exists(outdir):
		os.mkdir(outdir)
	os.chdir(outdir)
	
	jp2file = args.infile

	tiffile = path.join(outdir, path.basename(path.splitext(jp2file)[0] + '.tif'))
	rgbfile = path.join(outdir, path.basename(path.splitext(jp2file)[0] + '.png'))

	crsWkt = getCRS(jp2file)

	ul = convertCoordToWkt(bbox[3], bbox[2], crsWkt)
	lr = convertCoordToWkt(bbox[1], bbox[0], crsWkt)
	target_extent = "{} {} {} {}".format(ul[0], ul[1], lr[0], lr[1])
	os.system("gdalwarp -overwrite -te {} {} {}".format(
	   	target_extent,
		jp2file,
		tiffile #input dir
		))

	#export to PNG
	if path.exists(tiffile):
		print("exporting to PNG : {}".format(path.basename(rgbfile)))
		os.system("gdal_translate {} {}".format(tiffile, rgbfile))
		os.system("rm {}".format(tiffile))
