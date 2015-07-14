#
# Markus Schmidberger, schmidbe@amazon.de
# July 14, 2015
# This is the user-interface definition of the Shiny based IoT Sensor Demo.
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

library(shinydashboard)
library(shinyBS)
library(dplyr)
library(ggvis)
library(leaflet)
library(RCurl)

az <- httpGET("http://169.254.169.254/latest/meta-data/placement/availability-zone")
regionshort <- toupper(substr(az,1,2))

ui <- dashboardPage(
  
  dashboardHeader(
    title = paste("IoT Sensor Demo", regionshort),
    dropdownMenuOutput("dropdownMenu")
    ),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Alarm details", tabName = "alarms", icon = icon("warning")),
      menuItem("Raw data", tabName = "rawdata", icon = icon("th")),
      menuItem("Simulating Data", tabName = "simulation", icon = icon("random")),
      menuItem("Description", tabName = "description", icon = icon("info-circle"))
    ),
    sliderInput("refresh", label = "Refresh every (secs):", min = 3, 
                max = 15, value = 5),
    sliderInput("show", label = "Display time (secs):", min = 5, 
                max = 240, value = 60, step=10),
    sliderInput("clearMessTime", label = "Delete Messages after (secs)", min = 15, 
                max = 240, value = 60, step=30),
    selectInput("agg", "Aggregation:",
                c("No" = 5,
                  "10ms"=2,
                  "100ms"=1,
                  "1s" = 0,
                  "10s" = -1), selected=5)
  ),
  
  
  dashboardBody(
    tabItems(
      tabItem("dashboard",
        fluidRow(
          column(8,
            box(width = NULL, status = "info", solidHeader = TRUE,
                title = "Device Motion - Acceleration Including Gravity",
                collapsible = TRUE,
                ggvisOutput("accX"),
                ggvisOutput("accY"),
                ggvisOutput("accZ"),
                p("All data in screen-adjusted system")
            ),
            box(width = NULL, status = "info", solidHeader = TRUE,
                title = "Device Orientation",
                collapsible = TRUE,
                ggvisOutput("devOrA"),
                uiOutput("devOrA_ui"),
                ggvisOutput("devOrB"),
                uiOutput("devOrB_ui"),
                ggvisOutput("devOrG"),
                uiOutput("devOrG_ui"),
                p("All data in screen-adjusted system")
            )
          ),
          column(4,
                 uiOutput("nrdevices"),
                 uiOutput("nrreadssecs"),
                 uiOutput("MBreadssecs"),
                 uiOutput("deltaT"),
                 uiOutput("deltaTavg"),
                 h3("Alarms:"),
                 bsAlert("alert_anchor")
          )
        )
      ),
      
      tabItem("map",
              h2("Device Geo Locations"),
              leafletOutput('myMap')),
      
      tabItem("rawdata",
              numericInput("maxrows", "Rows to show", 10),
              h4("Orientation Sensor Data"),
              verbatimTextOutput("rawtableOrientation"),
              h4("Motion Sensor Data"),
              verbatimTextOutput("rawtableMotion"),
              downloadButton("downloadOrientationCsv", "Download Orientation as CSV"),
              downloadButton("downloadMotionCsv", "Download Motion as CSV")
      ),
      
      tabItem(tabName = "alarms",
              fluidRow(
                  uiOutput("alarmnrdevices"),
                  uiOutput("alarmnrdatapoints")
                ),
              fluidRow(
                column(8,
                       h2("Alarm Details"),
                       box(width = NULL, status = "info", solidHeader = TRUE,
                           title = "Device Motion - Freefall Analyses",
                           collapsible = TRUE,
                           ggvisOutput("freefallPlot"),
                           p("Only plotting the newest data from Kinesis. If x+z+y == 0 we report 'freefall'.")
                       ),
                       box(width = NULL, status = "info", solidHeader = TRUE,
                           title = "Device Motion - Variance Analyses",
                           collapsible = TRUE,
                           ggvisOutput("variancePlot"),
                           p("Only plotting the newest data from Kinesis. If variance is 5 times bigger than average variance we report 'shaking'.")
                       ),
                       box(width = NULL, status = "info", solidHeader = TRUE,
                           title = "Device Orientation",
                           collapsible = TRUE,
                           ggvisOutput("devOrientBoxplot")
                       ),
                       box(width = NULL, status = "info", solidHeader = TRUE,
                           title = "Device Motion - Acceleration Including Gravity",
                           collapsible = TRUE,
                           ggvisOutput("devMotionBoxplot")
                       )
                ),
                column(4,
                       h3("Alarms:"),
                       bsAlert("alert_anchor2")
                )
              )
      ),
      
      tabItem(tabName = "simulation",
              fluidRow(
                column(12,
                       h2("Simulating iPhone Device Sensor Data"),
                       wellPanel(
                          sliderInput("simnrdevices", label = h3("# Devices"), min = 1, 
                                      max = 50, value = 20),
                          sliderInput("simtime", label = h3("Simulation time in min"), min = 1, 
                                      max = 10, value = 3),
                          sliderInput("sendtime", label = h3("Send every secs"), min = 1, 
                                      max = 10, value = 3),
                          actionButton("startSim", "Start Simulation")
                       ),
                       verbatimTextOutput("simOut")
                )
              )
      ),
      
      tabItem(tabName = "description",
              fluidRow(
                column(8,
                  h2("Sensor Description"),
                  h3("Producer Webpage URL"),
                  a("http://iot.aws-cloudlab.org", 
                    href="http://iot.aws-cloudlab.org",
                    target="_blank"),                  
                  h3("Device Motion"),
                  p("Describes the acceleration of your device in a coordinate frame with three axes, x, y and z. 
                    This is measured in meters per second squared (m/s^2). 
                    Data from the accelerometer sensor are used and include the Earth's gravity. 
                    When your device is placed on a flat table, it should display about 9.807 m/s^2.
                    "),
                  p("Device motion events also provide rotation data. These are computed from the raw accelerometer data. 
                    These values are inferior to the gyroscope / device orientation in terms of accuracy and range.
                    We currently do not track these data."),
                  h3("Device Orientation"),
                  p("The device orientation event returns only the rotation data, 
                    which includes how much the device is leaning front-to-back (beta), side-to-side (gamma) 
                    and the direction the device is facing (alpha). Data from the gyroscope sensor are used"),
                  h3("More Device Details"),
                  p("Good readings with more details about accessing device sensors are available at:"),
                  a("http://www.html5rocks.com/en/tutorials/device/orientation", 
                    href="http://www.html5rocks.com/en/tutorials/device/orientation",
                    target="_blank"),
                  br(),
                  a("http://w3c.github.io/deviceorientation/spec-source-orientation.html", 
                    href="http://w3c.github.io/deviceorientation/spec-source-orientation.html",
                    target="_blank"),
                  h3("More Demo Details"),
                  p("Code and documentation:",
                  a("https://github.com/schmidb/amazon-kinesis-IoT-sensor-demo", 
                    href="https://github.com/schmidb/amazon-kinesis-IoT-sensor-demo",
                    target="_blank")),
                  p("Presentation:",
                  a("Thing Big: How to Scale Your Own Internet of Things", 
                    href="http://aws-de-media.s3.amazonaws.com/images/AWS%20Summit%20Berlin%202015/Praesentationen_Berlin_Summit_2015/Praesentationen_Berlin_Summit_2015_enterprise/4h50_ENT2_Think_Big_IoT.pdf",
                    target="_blank"))
                ),
                column(4,
                       img(src="http://www.html5rocks.com/en/tutorials/device/orientation/axes.png"),
                       img(src="http://w3c.github.io/deviceorientation/a-rotation.png")
                  )
              )
      )
    )
  )
)

