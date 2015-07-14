from boto import kinesis
import urllib

# we assume that Kinesis is running in same region
REGION = urllib.urlopen('http://169.254.169.254/latest/meta-data/placement/availability-zone').read()[:-1]
STREAMNAME = 'IoTSensorDemo'

# Kinesis connection
kinesisConn = kinesis.connect_to_region(REGION)
