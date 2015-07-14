# Amazon Kinesis IoT Sensor Demo

Internet of Things (IoT) is a big topic for many AWS customers. This prototype is a very simple IoT showcase to demonstrate how fast data from sensors can be send to AWS (http://aws.amazon.com/) and analysed on AWS. The demo only requires one or two participants with smartphones, but scales up to 300 participants without performance issues. 

## Idea
Use your mobile device (smartphone, tablet) to visit a simple webpage on Amazon S3 (http://aws.amazon.com/s3/). This webpage uses JavaScript to track the movement of your device (via motion sensor) and sends these data to AWS. In the AWS Cloud we use Amazon Kinesis (http://aws.amazon.com/kinesis/) to collect all data. The statistical software R (http://www.r-project.org/) is used to process and analyse the data. Using R packages as shiny and ggplot2 a realtime dashboard is created. On this realtime dashboard you can see the movement of all connected devices. Furthermore, using simple statistical algorithms you can identify special movements as freefall or shaking.

## Installation
1. Create Amazon Kinesis Stream
2. Create Amazon Cognito Identity Pool
    1. Add policy to unauthorized role with permissions to write into your Kinesis stream
3. Create IAM role with permission for reading and writing your Kinesis stream
4. Set-up EC2 server
    1. Add IAM role to access Kinesis
    2. Choose Amazon Linux AMI and use "install_AmazonLinux" script to install required software"
    3. Download code from github and configure


----
Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Amazon Software License (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

http://aws.amazon.com/asl/
