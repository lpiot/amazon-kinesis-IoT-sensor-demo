#!/bin/bash
#
# Markus Schmidberger, schmidbe@amazon.de
# July 14, 2015
# User Data / bootstrap script to install software on EC2 server. Installing
# * R
# * shiny
# * required packages for shiny based IoT Sensor Demo dashboard
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

# update server
yum update -y

# install R
yum install R -y

# install RStudio -> not required
#wget http://download2.rstudio.org/rstudio-server-rhel-0.99.442-x86_64.rpm
#sudo yum install -y --nogpgcheck rstudio-server-rhel-0.99.442-x86_64.rpm
#sudo /bin/sh -c 'echo "www-port=443" >> /etc/rstudio/rserver.conf'
#sudo restart rstudio-server

# install shiny package
R -e "install.packages('shiny', repos='http://cran.rstudio.com/')"

# install shiny server
wget http://download3.rstudio.org/centos-5.9/x86_64/shiny-server-1.3.0.403-rh5-x86_64.rpm
yum install -y --nogpgcheck shiny-server-1.3.0.403-rh5-x86_64.rpm

# install packages required for IoT Demo
R -e "install.packages(c('DBI', 'BH'), repos='http://cran.rstudio.com/')"
R -e "install.packages(c('assertthat', 'magrittr', 'lazyeval'), repos='http://cran.rstudio.com/')"
wget https://github.com/hadley/dplyr/archive/v0.4.0.tar.gz
R CMD INSTALL v0.4.0.tar.gz
yum install -y libpng-devel
yum install -y libcurl-devel
R -e "install.packages(c('ggvis', 'rPython', 'shinydashboard', 'shinyBS', 'leaflet','RCurl'), repos='http://cran.rstudio.com/')"


# install git and clone repo
yum install -y git
mkdir /home/ec2-user/amazon-kinesis-IoT-sensor-demo
git clone https://github.com/schmidb/amazon-kinesis-IoT-sensor-demo.git /home/ec2-user/amazon-kinesis-IoT-sensor-demo
chown ec2-user:ec2-user -R /home/ec2-user/amazon-kinesis-IoT-sensor-demo

# change config for www producer
sed -i -- 's/arn:aws:iam::374311255271:role\/Cognito_IoTSensorDemoUnauth_DefaultRole/XXXXXXX/g' /home/ec2-user/amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
sed -i -- 's/374311255271/XXXXXXX/g' /home/ec2-user/amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
sed -i -- 's/eu-west-1:b23b2b5b-b1c8-45ff-b7fb-3dd73c8f1466/XXXXXX/g' /home/ec2-user/amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
sed -i -- "s/'eu-west-1'/'XXXXXX'/g" /home/ec2-user/amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js

# copy shiny-server config and restart shiny-server
cp /home/ec2-user/amazon-kinesis-IoT-sensor-demo/src/install/shiny-server.conf /etc/shiny-server/shiny-server.conf
restart shiny-server

# add time sync to avoid server running out of time
yum install -y ntp ntpdate ntp-doc
chkconfig ntpd on
ntpdate pool.ntp.org
/etc/init.d/ntpd start
