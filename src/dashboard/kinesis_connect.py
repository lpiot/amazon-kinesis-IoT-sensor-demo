#
# Markus Schmidberger, schmidbe@amazon.de
# July 14, 2015
# Python Connector to Kinesis in same region
#
####################
#
# Copyright 2014, Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
# http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#
#####################

from boto import kinesis
import urllib

# we assume that Kinesis is running in same region
REGION = urllib.urlopen('http://169.254.169.254/latest/meta-data/placement/availability-zone').read()[:-1]
STREAMNAME = 'IoTSensorDemo'

# Kinesis connection
kinesisConn = kinesis.connect_to_region(REGION)
