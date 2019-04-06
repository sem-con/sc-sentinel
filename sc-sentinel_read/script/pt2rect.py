import os
from osgeo import osr, ogr, gdal
from math import cos, sin, asin, sqrt, radians, degrees

DEFAULT_EPSG=4326 #WGS84 Datum

def get_datum_radius(epsg=DEFAULT_EPSG):
	crs = osr.SpatialReference()
	crs.ImportFromEPSG(epsg)
	wkt = crs.ExportToWkt()
	return float(wkt[wkt.index('SPHEROID'):wkt.index('AUTHORITY')].split(',')[1])

def get_bounding_rect(lat, lng, radius, datum_radius):
	dLat = degrees(radius / datum_radius)
	dLng = degrees(radius / datum_radius / cos(radians(lat)))
	return lat + dLat, lng + dLng, lat - dLat, lng - dLng

def haversine(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    """
    # convert decimal degrees to radians 
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    # haversine formula 
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    # Radius of earth in kilometers
    km = get_datum_radius()*1e-3* c
    return km

def convertCoordToWkt(lng, lat, wkt, epsgFrom=4326):
    crs = osr.SpatialReference()
    crs.ImportFromWkt(wkt)
    wgs = osr.SpatialReference()
    wgs.ImportFromEPSG(epsgFrom)
    transform = osr.CoordinateTransformation(wgs, crs)
    pt = ogr.CreateGeometryFromWkt("POINT({} {})".format(lng, lat))
    pt.Transform(transform)
    return pt.GetX(), pt.GetY()

def getCRS(filename):
    ds = gdal.Open(filename)
    crs = None
    if ds is not None:
        crs = ds.GetProjection()
        ds = None
    return crs

def getEPSGFromWkt(wkt):
    return int(wkt[wkt.rindex("AUTHORITY"):].split('"')[3])

def getSAFEImageDir(safedir):
    dname = os.listdir(os.path.join(safedir, 'GRANULE'))[0]
    return os.path.join(safedir, 'GRANULE', dname, 'IMG_DATA')

def getSAFEMeta(safedir):
    dname = os.listdir(os.path.join(safedir, 'GRANULE'))[0]
    return os.path.join(safedir, 'GRANULE', dname, 'MTD_TL.xml')

def getSAFEEPSG(safedir):
    meta = getSAFEMeta(safedir)
    epsg = -1
    with open(meta) as fm:
        for line in fm:
            if "EPSG:" in line:
                epsg = int(line[line.index('EPSG:')+5:line.index('/')-1])
                break

    return epsg

def getWKTFromEpsg(epsg):
    sr = osr.SpatialReference()
    sr.ImportFromEPSG(epsg)
    return sr.ExportToWkt()

if __name__=="__main__":
	print(get_datum_radius()*1e-3)
	print(get_bounding_rect(48.2082, 16.3738, 5, get_datum_radius()*1e-3))

	assert (haversine(*get_bounding_rect(16.3738, 48.2082, 5., get_datum_radius()*1e-3))-(10*sqrt(2)))<1e-3