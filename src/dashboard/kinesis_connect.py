from boto import kinesis

#REGION = 'us-west-2'
REGION = 'eu-central-1'
STREAMNAME = 'IoTSensorDemoEUCentral'

# Kinesis connection
kinesisConn = kinesis.connect_to_region(REGION)
