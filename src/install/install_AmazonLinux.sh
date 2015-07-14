#
# Markus Schmidberger, schmidbe@amazon.de
# July 14, 2015
# Install / bootstrap script for EC2 server. Installing
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
sudo yum update -y

# install R
sudo yum install R -y


# install RStudio -> not required
#wget http://download2.rstudio.org/rstudio-server-rhel-0.99.442-x86_64.rpm
#sudo yum install -y --nogpgcheck rstudio-server-rhel-0.99.442-x86_64.rpm
#sudo /bin/sh -c 'echo "www-port=443" >> /etc/rstudio/rserver.conf'
#sudo restart rstudio-server

# install shiny package
sudo su - \
-c "R -e \"install.packages('shiny', repos='http://cran.rstudio.com/')\""

# install shiny server
wget http://download3.rstudio.org/centos-5.9/x86_64/shiny-server-1.3.0.403-rh5-x86_64.rpm
sudo yum install -y --nogpgcheck shiny-server-1.3.0.403-rh5-x86_64.rpm

# install packages required for IoT Demo
sudo su - \
-c "R -e \"install.packages(c('DBI', 'BH'), repos='http://cran.rstudio.com/')\""

wget https://github.com/hadley/dplyr/archive/v0.4.0.tar.gz
sudo R CMD INSTALL v0.4.0.tar.gz 

sudo yum install -y libpng-devel
sudo yum install -y libcurl-devel

sudo su - \
-c "R -e \"install.packages(c('ggvis', 'rPython', 'shinydashboard', 'shinyBS', 'leaflet'), repos='http://cran.rstudio.com/')\""

sudo su - \
-c "R -e \"install.packages(c('RCurl'), repos='http://cran.rstudio.com/')\""


# install git and clone repo
sudo yum install -y git
git clone https://github.com/schmidb/amazon-kinesis-IoT-sensor-demo.git

# change config for www producer
# sudo sed -i -- 's/arn:aws:iam::374311255271:role/Cognito_IoTSensorDemoUnauth_DefaultRole/YOURROLE/g' amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
# sudo sed -i -- 's/374311255271/YOURACCOUNTID/g' amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
# sudo sed -i -- 's/eu-west-1:b23b2b5b-b1c8-45ff-b7fb-3dd73c8f1466/YOURIDENTITYPOOL/g' amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js
# sudo sed -i -- 's/eu-west-1/YOURREGION/g' amazon-kinesis-IoT-sensor-demo/src/www/iotdemo.js

# copy shiny-server config and restart shiny-server
sudo cp amazon-kinesis-IoT-sensor-demo/src/install/shiny-server.conf /etc/shiny-server/shiny-server.conf
sudo restart shiny-server

# add time sync to avoid server running out of time
sudo yum install -y ntp ntpdate ntp-doc
sudo chkconfig ntpd on
sudo ntpdate pool.ntp.org
sudo /etc/init.d/ntpd start
