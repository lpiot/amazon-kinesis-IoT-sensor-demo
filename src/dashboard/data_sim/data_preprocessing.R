#
# Markus Schmidberger, schmidbe@amazon.de
# July 14, 2015
# Script to convert recorded data into correct format for simulation.
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

library(dplyr)

write.table(dataMotion, 
            file="data_sim/data/cleanSimData_Motion.csv", 
            row.names = TRUE, sep=",")

write.table(dataOrientation, 
            file="data_sim/data/cleanSimData_Orientation.csv", 
            row.names = TRUE, sep=",")

write.table(dataGeo, 
            file="data_sim/data/cleanSimData_Geo.csv", 
            row.names = TRUE, sep=",")

# manually add empty header at first position.