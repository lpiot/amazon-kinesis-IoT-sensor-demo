# This is the server logic for a Shiny web application.

library(shinydashboard)
library(shinyBS)
library(rPython)
library(ggvis)
library(leaflet)
#library(dplyr)
library(parallel)


server <- function(input, output, session) {
  
  # to deal correctly with milliseconds in timestamp
  options(digits=15)
  
  ################
  # Connect to Kinesis Stream
  python.load("kinesis_connect.py")
  python.exec("siterator = kinesisConn.get_shard_iterator(STREAMNAME,'shardId-000000000000','LATEST')")
  siterator <- python.get("siterator")
  
  ##########
  # data object PROTOTYPES
  dataOrientation <- data.frame(ip = character(), recordTime = integer(),
                          cognitoId = character(),
                          device = character(), sensorname = character(),
                          alpha = numeric(), beta = numeric(), gamma = numeric(),
                          stringsAsFactors=FALSE)
  dataMotion <- data.frame(ip = character(), recordTime = integer(),
                                cognitoId = character(),
                                device = character(), sensorname = character(),
                                x = numeric(), y = numeric(), z = numeric(),
                                stringsAsFactors=FALSE)
  dataGeo <- data.frame(ip = character(), recordTime = integer(),
                                cognitoId = character(),
                                device = character(), sensorname = character(),
                                lat = numeric(), long = numeric(),
                                stringsAsFactors=FALSE)  
  messageData <- data.frame(text=character(),
                            cognitoId=character(),
                            status=character(),
                            createdAt=character(),
                            viz=integer(),
                            vizAPI=integer(), 
                            stringsAsFactors=FALSE)
  
  ##########
  # READ new data from Kinesis Stream
  getDataFromStream <- reactive({
    
    invalidateLater(as.integer(input$refresh) * 1000, session)
    
    # get records via python and set sharditerator
    res <- python.call("kinesisConn.get_records", siterator[["ShardIterator"]])
    siterator[["ShardIterator"]] <<- res$NextShardIterator
   
    data_new_Orientation <- mclapply(res$Records, function(x) {
      if(x["PartitionKey"]=="screenAdjustedEvent"){
        unlist(fromJSON(x["Data"]))[c("recordTime", "cognitoId", "device", "sensorname","alpha","beta","gamma")] }})
    data_new_Orientation <- as.data.frame(do.call(rbind, data_new_Orientation), stringsAsFactors=FALSE) 
    if(length(data_new_Orientation)!=0){  
      colnames(data_new_Orientation) <- c("recordTime", "cognitoId", "device", "sensorname","alpha","beta","gamma")
    }
    data_new_Motion <- mclapply(res$Records, function(x) {
      if(x["PartitionKey"]=="screenAccG"){
        unlist(fromJSON(x["Data"]))[c("recordTime", "cognitoId", "device", "sensorname","x","y","z")] }})
    data_new_Motion <- as.data.frame(do.call(rbind, data_new_Motion), stringsAsFactors=FALSE) 
    if(length(data_new_Motion)!=0){
      colnames(data_new_Motion) <- c("recordTime", "cognitoId", "device", "sensorname","x","y","z")
    }
    data_new_Geo <- mclapply(res$Records, function(x) {
      if(x["PartitionKey"]=="geoLocation"){
        unlist(fromJSON(x["Data"]))[c("recordTime", "cognitoId", "device", "sensorname","lat","long")] }})
    data_new_Geo <- as.data.frame(do.call(rbind, data_new_Geo), stringsAsFactors=FALSE) 
    if(length(data_new_Geo)!=0){
      colnames(data_new_Geo) <- c("recordTime", "cognitoId", "device", "sensorname","lat","long")
    }
    
    ########
    # Data corrections for format
     if( length(data_new_Orientation) != 0 ){
              data_new_Orientation$recordTime <- as.numeric(data_new_Orientation$recordTime)
              data_new_Orientation$alpha <- as.numeric(data_new_Orientation$alpha)
              data_new_Orientation$beta <- as.numeric(data_new_Orientation$beta)
              data_new_Orientation$gamma <- as.numeric(data_new_Orientation$gamma)
             
             # omit null ids and na recordTimes
              data_new_Orientation <- data_new_Orientation %>% filter(cognitoId != "null")
              data_new_Orientation <- data_new_Orientation %>% filter(!is.na(recordTime))
           
             # remove phones with timestamps in the future 
              data_new_Orientation <- data_new_Orientation %>% filter(recordTime < as.numeric(Sys.time()))
     }
    
     if( length(data_new_Motion) != 0 ){
        data_new_Motion$recordTime <- as.numeric(data_new_Motion$recordTime)
        data_new_Motion$x <- as.numeric(data_new_Motion$x)
        data_new_Motion$y <- as.numeric(data_new_Motion$y)
        data_new_Motion$z <- as.numeric(data_new_Motion$z)
        
        # omit null ids and na recordTimes
        data_new_Motion <- data_new_Motion %>% filter(cognitoId != "null")
        data_new_Motion <- data_new_Motion %>% filter(!is.na(recordTime))
        data_new_Motion <- data_new_Motion %>% filter(!is.na(x))
        data_new_Motion <- data_new_Motion %>% filter(!is.na(y))
        data_new_Motion <- data_new_Motion %>% filter(!is.na(z))
        # remove phones with timestamps in the future 
        data_new_Motion <- data_new_Motion %>% filter(recordTime < as.numeric(Sys.time()))
     }
    

    
     if( length(data_new_Geo) != 0 ){
      data_new_Geo$recordTime <- as.numeric(data_new_Geo$recordTime)
      data_new_Geo$lat <- as.numeric(data_new_Geo$lat)
      data_new_Geo$long <- as.numeric(data_new_Geo$long)
      
      # omit null ids and na recordTimes
      data_new_Geo <- data_new_Geo %>% filter(cognitoId != "null")
      data_new_Geo <- data_new_Geo %>% filter(!is.na(recordTime))
      
      # remove phones with timestamps in the future 
      data_new_Geo <- data_new_Geo %>% filter(recordTime < as.numeric(Sys.time()))
    }
    
     list(data_new_Orientation, data_new_Motion, data_new_Geo)
  })

  getNewOrientationData <- reactive({
    data <- getDataFromStream()
    data[[1]]
  })
  getNewMotionData <- reactive({
    data <- getDataFromStream()
    data[[2]]
  })
  getNewGeoData <- reactive({
    data <- getDataFromStream()
    data[[3]]
  })
  
  ############
  # ALARMS based on new data from stream
  newDataAlarms <- reactive({
     
     data_new_Orientation <- getNewOrientationData()
     data_new_Motion <- getNewMotionData()
     data_new_Geo <- getNewGeoData()
     
     ###############
     # Data aggregation
     if( input$agg != 5 ){
        data_new_Orientation <- data_new_Orientation %>% 
            mutate(recordTime=round(recordTime, 
                                    digits=as.integer(input$agg))) %>%
            group_by(recordTime, cognitoId, sensorname, device) %>%
            summarise(alpha=mean(alpha),
                      beta=mean(beta),
                      gamma=mean(gamma))
        data_new_Motion <- data_new_Motion %>% 
            mutate(recordTime=round(recordTime, 
                                    digits=as.integer(input$agg))) %>%
            group_by(recordTime, cognitoId, sensorname, device) %>%
            summarise(x=mean(x),
                      y=mean(y),
                      z=mean(z))
        data_new_Geo <- data_new_Geo %>% 
            mutate(recordTime=round(recordTime, 
                                    digits=as.integer(input$agg))) %>%
            group_by(recordTime, cognitoId, sensorname, device) %>%
            summarise(lat=mean(lat),
                      long=mean(long))
     }

    # Freefall warning
    if( length(data_new_Motion) != 0 ){
        freefall <- data_new_Motion %>% 
              filter(sensorname=="screenAccG") %>%
              mutate(xr=round(x), yr=round(y), zr=round(z)) %>% 
              filter(xr==0 & yr == 0 & zr ==0)
      for(free in unique(freefall$cognitoId)){
        print(free)
             lfree <- nchar(free)
             if(! (free %in% messageData$cognitoId)) {
                      messageData <- rbind(messageData,
                                           data.frame(text=paste("Freefall for ...",substr(free,lfree-5,lfree), sep=""), 
                                                    cognitoId=free, status="danger",
                                                    createdAt=Sys.time(), viz=0, vizAPI=0,
                                                    stringsAsFactors=FALSE))
             }
      }
     
    }
    
    # Shaking warning
    if( length(data_new_Motion) != 0 ){
      varall <- varianceAllData()
      shaking <- data_new_Motion %>% 
          filter(sensorname=="screenAccG") %>%
          group_by(cognitoId) %>% 
          summarise(varx=var(x), vary=var(y), varz=var(z))
      shake <- shaking %>%
          filter(varx > 5 * varall$varx | vary > 5 * varall$vary | varz > 5 * varall$varz )
      
      for(s in unique(shake$cognitoId)){
          ls <- nchar(s)
          if(! (s %in% messageData$cognitoId) ){
                  messageData <- rbind(messageData,
                               data.frame(text=paste("Shaking for ...",substr(s,ls-5,ls), sep=""), 
                                    cognitoId=s, status="danger",
                                    createdAt=Sys.time(), viz=0, vizAPI=0,
                                    stringsAsFactors=FALSE))
          }
      }
      
    }
    
    # remove old messages
    messageDataDel <- messageData %>% 
          filter(as.numeric(createdAt) <= as.numeric(Sys.time()) - input$clearMessTime )
    for(id in unique(messageDataDel$cognitoId)){
          closeAlert(session, as.character(id))
    }
    messageData <- messageData %>% 
      filter(as.numeric(createdAt)  > as.numeric(Sys.time()) - input$clearMessTime )
    
    messageData <<- messageData
    
    messageData
  })
  
  ###########
  # COMBINE data and do data aggregation
  combineData <- reactive({
    
    data_new_Orientation <- getNewOrientationData()
    data_new_Motion <- getNewMotionData()
    data_new_Geo <- getNewGeoData()
    
    #######
    # Combine data_new and data old
    if( dim(dataOrientation)[1]==0 && length(data_new_Orientation) != 0 ){
      dataOrientation <- data_new_Orientation
    } else if(length(data_new_Orientation) != 0) {      
      dataOrientation <- as.data.frame( rbind(dataOrientation,data_new_Orientation), stringsAsFactors=FALSE)
    }
    if( dim(dataMotion)[1]==0 && length(data_new_Motion) != 0 ){
      dataMotion <- data_new_Motion
    } else if(length(data_new_Motion) != 0) {      
      dataMotion <- as.data.frame( rbind(dataMotion,data_new_Motion), stringsAsFactors=FALSE)
    }
    if( dim(dataGeo)[1]==0 && length(data_new_Geo) != 0 ){
      dataGeo <- data_new_Geo
    } else if(length(data_new_Geo) != 0) {      
      dataGeo <- as.data.frame( rbind(dataGeo,data_new_Geo), stringsAsFactors=FALSE)
    }
    
    ###########
    # remove very old data (bigger than 240 secs)
    dataOrientation <- dataOrientation %>% filter(recordTime > ( as.numeric(Sys.time()) - 240) )
    dataMotion <- dataMotion %>% filter(recordTime > ( as.numeric(Sys.time()) - 240) )
    dataGeo <- dataGeo %>% filter(recordTime > ( as.numeric(Sys.time()) - 240) )
    

    ##############
    # store data before aggregation
    # DO WE NEED THAT?
    dataOrientation <<- dataOrientation
    dataMotion <<- dataMotion
    dataGeo <<- dataGeo
    
    ###############
    # Data aggregation
     if( input$agg != 5 ){
       dataOrientation <- dataOrientation %>% 
             mutate(recordTime=round(recordTime, 
                                     digits=as.integer(input$agg))) %>%
             group_by(recordTime, cognitoId, sensorname, device) %>%
             summarise(alpha=mean(alpha),
                       beta=mean(beta),
                       gamma=mean(gamma))
       dataMotion <- dataMotion %>% 
             mutate(recordTime=round(recordTime, 
                                     digits=as.integer(input$agg))) %>%
             group_by(recordTime, cognitoId, sensorname, device) %>%
             summarise(x=mean(x),
                       y=mean(y),
                       z=mean(z))
       dataGeo <- dataGeo %>% 
             mutate(recordTime=round(recordTime, 
                                     digits=as.integer(input$agg))) %>%
             group_by(recordTime, cognitoId, sensorname, device) %>%
             summarise(lat=mean(lat),
                       long=mean(long))
     }
    
    ##################
    #debugging
    assign("dataOrientation",dataOrientation, env=.GlobalEnv)
    assign("dataMotion",dataMotion, env=.GlobalEnv)
    assign("dataGeo",dataGeo, env=.GlobalEnv)
    
    list(dataOrientation, dataMotion, dataGeo)
  }) 
  getOrientationData <- reactive({
    data <- combineData()
    data[[1]]
  })
  getMotionData <- reactive({
    data <- combineData()
    data[[2]]
  })
  getGeoData <- reactive({
    data <- combineData()
    data[[3]]
  })
  
  
  ######################
  # GRAPHS
  
  # Device Orientation
  devOrA <- reactive({
    streamdata <- getOrientationData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata 
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAdjustedEvent") %>%     
        filter(recordTime > max(recordTime) - as.integer(input$show)) 
    }
    out %>% group_by(cognitoId)
  })
  devOrA %>% ggvis(x = ~recordTime, 
                   y = ~alpha, 
                   stroke = ~factor(cognitoId)) %>%
        layer_lines() %>%
        hide_legend("stroke") %>%
        hide_axis("x") %>%
        add_axis("y", title = "Alpha") %>%
        set_options(height=100, width=NULL, duration=0) %>%
        bind_shiny("devOrA","devOrA_ui") 
  
  devOrB <- reactive({
    streamdata <- getOrientationData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAdjustedEvent") %>% 
        filter(recordTime > max(recordTime) - as.integer(input$show))        
    }
    out %>% group_by(cognitoId)
      
  })
  devOrB %>% ggvis(x = ~recordTime, 
                   y = ~beta, 
                   stroke = ~factor(cognitoId)) %>% 
        layer_lines() %>%
        hide_legend("stroke") %>%
        hide_axis("x") %>%
        add_axis("y", title = "Beta") %>%
        set_options(height=100, width=NULL, duration=1) %>%
        bind_shiny("devOrB","devOrB_ui") 
  
  devOrG <- reactive({
    streamdata <- getOrientationData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAdjustedEvent") %>% 
        filter(recordTime > max(recordTime) - as.integer(input$show)) 
    }
    out %>% group_by(cognitoId)
  })
  devOrG %>% ggvis(x = ~recordTime, 
                   y = ~gamma, 
                   stroke = ~factor(cognitoId)) %>%
          layer_lines() %>%
          hide_legend("stroke") %>%
          hide_axis("x") %>%
          add_axis("y", title = "Gamma") %>%
          set_options(height=100, width=NULL, duration=2) %>%
          bind_shiny("devOrG","devOrG_ui") 
  
  
  # Acceleration
  screenAccGX <- reactive({
    streamdata <- getMotionData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata 
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAccG") %>% 
        filter(recordTime > max(recordTime) - as.integer(input$show)) 
    }
    out %>% group_by(cognitoId)
  })
  screenAccGX %>% 
        ggvis(x = ~recordTime, 
              y = ~x,
              stroke = ~factor(cognitoId)) %>%
        layer_lines() %>%
        add_legend("stroke", title="Devices") %>%
        hide_axis("x") %>%
        add_axis("y", title = "X") %>%
        set_options(height=100, width=NULL) %>%
        bind_shiny("accX") 
  
  screenAccGY <- reactive({
    streamdata <- getMotionData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata 
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAccG") %>% 
        filter(recordTime > max(recordTime) - as.integer(input$show)) 
    }
    out %>% group_by(cognitoId)
  })
  screenAccGY %>% ggvis(x = ~recordTime, 
                        y = ~y, 
                        stroke = ~factor(cognitoId)) %>%
          layer_lines() %>%
          hide_legend("stroke") %>%
          hide_axis("x") %>%
          add_axis("y", title = "Y") %>%
          set_options(height=100, width=NULL) %>%
          bind_shiny("accY")  
  
  screenAccGZ <- reactive({
    streamdata <- getMotionData()
    if( dim(streamdata)[1] == 0) {
      out <- streamdata 
    } else {
      out <- streamdata %>% 
        filter(sensorname == "screenAccG") %>% 
        filter(recordTime > max(recordTime) - as.integer(input$show)) 
    }
    out %>% group_by(cognitoId)
  })
  screenAccGZ %>% ggvis(x = ~recordTime, 
                        y = ~z, 
                        stroke = ~factor(cognitoId)) %>%
            layer_lines() %>%
            hide_legend("stroke") %>%
            hide_axis("x") %>%
            add_axis("y", title = "Z") %>%
            set_options(height=100, width=NULL) %>% 
            bind_shiny("accZ") 


  
#   # Device type
#   # ToDo no updates ???
#   devType <- reactive({
#     newstreamdata <- getMotionData()
#     
#     if( dim(newstreamdata)[1] == 0) {
#       out <- data.frame(device=character())
#     } else {
#       out <- newstreamdata %>% 
#         group_by(device, cognitoId) %>% 
#         summarise(length(device))  
#     }   
#   out
#   }) 
#   devType %>% ggvis(~device) %>%
#     layer_bars() %>%
#     add_axis("x", title = "Device type") %>%
#     set_options(height=150, width=NULL) %>%
#     bind_shiny("deviceTypes") 
#   


  #######################
  # Map
  output$myMap <- renderLeaflet({
    dataGeo <- getGeoData()
    dataGeoSplit <- by(dataGeo[, c("lat", "long")], dataGeo$cognitoId, function(x)x)
    dataGeoSplit <- lapply(dataGeoSplit, function(x)rbind(x, NA))
    dataGeoSplit <- do.call(rbind, dataGeoSplit)
    palette("default")
    m <- leaflet() %>% addTiles() %>% 
          addPolylines(lng=round(dataGeoSplit$long,6), 
                       lat=round(dataGeoSplit$lat,6), 
                       fill = FALSE,
                       color=palette())
    m  
  })
   
  ########################
  # RAWDATA output
   output$rawtableMotion <- renderPrint({
     orig <- options(width = 1000)
     streamdata <- getMotionData()
     print(tail(streamdata[,-4], input$maxrows))
     options(orig)
   })
   output$rawtableOrientation <- renderPrint({
      orig <- options(width = 1000)
      streamdata <- getOrientationData()
      print(tail(streamdata[,-4], input$maxrows))
      options(orig)
    })
   output$rawtableGeo <- renderPrint({
      orig <- options(width = 1000)
      streamdata <- getGeoData()
      print(tail(streamdata[,-4], input$maxrows))
      options(orig)
    })
  
   output$downloadOrientationCsv <- downloadHandler(
     filename = "IoTSensorDemoDataOrientation.csv",
     content = function(file) {
       streamdata <- getOrientationData()
       streamdata <- streamdata %>% arrange(recordTime)
       write.csv(streamdata, file)
     },
     contentType = "text/csv"
   )
    output$downloadMotionCsv <- downloadHandler(
      filename = "IoTSensorDemoDataMotion.csv",
      content = function(file) {
        streamdata <- getMotionData()
        streamdata <- streamdata %>% arrange(recordTime)
        write.csv(streamdata, file)
      },
      contentType = "text/csv"
    )
    output$downloadGeoCsv <- downloadHandler(
      filename = "IoTSensorDemoDataGeo.csv",
      content = function(file) {
        streamdata <- getGeoData()
        streamdata <- streamdata %>% arrange(recordTime)
        write.csv(streamdata, file)
      },
      contentType = "text/csv"
    )
  
  ######################
  # ALARM Detail
  # ALARMS on top of page
   output$alarmnrdevices <- renderUI({
     newstreamdata <- getNewMotionData()
     if ( length(unique(newstreamdata$cognitoId)) < 3 ){
         box( paste( length(unique(newstreamdata$cognitoId)), "devices"),
           title="Number of devices sending data to small",
           solidHeader = TRUE, status = "warning", width = NULL)
     }
   })
 
   output$alarmnrdatapoints <- renderUI({
     streamdata <- getMotionData()
     newstreamdata <- getNewMotionData()
     if ( dim(streamdata)[1] < 300 || dim(newstreamdata)[1] == 0  ){
       box( paste( dim(streamdata)[1], "data points /",dim(newstreamdata)[1], "new data points"),
            title="Number of data points to small",
            solidHeader = TRUE, status = "warning", width = NULL)
     }
   })
   
  # Graphs
  devOrientBoxplot <- reactive({
    streamdata <- getOrientationData()
    streamdataAdjust <- streamdata %>% 
      filter(sensorname == "screenAdjustedEvent")  
    if( dim(streamdataAdjust)[1] == 0) {
      out <- data.frame(coord=c("alpha", "beta", "gamma"), values=0) 
    } else {
      dat <- as.data.frame( rbind(cbind("alpha", streamdataAdjust$alpha),
                                  cbind("beta", streamdataAdjust$beta),
                                  cbind("gamma", streamdataAdjust$gamma)) )
      names(dat) <- c("coord", "values")
      dat$values <- as.numeric(levels(dat$values))[dat$values]
      out <- dat
        
      
      # create meesages # 2 300
      if( length(unique(streamdataAdjust$cognitoId)) > 2 &&
            dim(streamdataAdjust)[1] > 300){
        
        if( exists("alarmOrientation") ){
          for(a in alarmOrientation){
            closeAlert(session, paste("orientation", alarmOrientation, sep="-"))
          }
        }
        
        alarmOrientation <- c()
        alpha <- boxplot.stats(streamdataAdjust$alpha, coef=7)
        for(i in alpha$out){
          id <- which(streamdataAdjust$alpha==i)
          alarmOrientation <- append(alarmOrientation, streamdataAdjust[id,]$cognitoId)
        }
        beta <- boxplot.stats(streamdataAdjust$beta)
        for(i in beta$out){
          id <- which(streamdataAdjust$beta==i)
          alarmOrientation <- append(alarmOrientation, streamdataAdjust[id,]$cognitoId)
        }
        gamma <- boxplot.stats(streamdataAdjust$gamma)
        for(i in gamma$out){
          id <- which(streamdataAdjust$gamma==i)
          alarmOrientation <- append(alarmOrientation, streamdataAdjust[id,]$cognitoId)
        }
        alarmOrientation <- unique( alarmOrientation )
        for( a in alarmOrientation){
          #createAlert(session, inputId = "alert_anchor",
          #            alertId = paste("orientation", alarmOrientation, sep="-"),
          #            message = paste("Device Orientation Warning for", alarmOrientation),
          #            type = "warning",dismiss = TRUE,block = FALSE,append = FALSE)
        }
      }
      
    }
    out
  })
  devOrientBoxplot %>% 
      ggvis(x = ~coord, 
            y = ~values) %>%
      layer_boxplots(coef=7) %>%
      set_options(height=150, width=NULL) %>%
      bind_shiny("devOrientBoxplot") 
  
  devMotionBoxplot <- reactive({
    streamdata <- getMotionData()
    streamdataAcc <- streamdata %>% 
                filter(sensorname == "screenAccG")
    if( dim(streamdataAcc)[1] == 0) {
      out <- data.frame(coord=c("x", "y", "z"), val=0)
    } else {
      dat <- as.data.frame( rbind(cbind("x", streamdataAcc$x),
                                  cbind("y", streamdataAcc$y),
                                  cbind("z", streamdataAcc$z)) )
      names(dat) <- c("coord", "val")
      dat$val <- as.numeric(levels(dat$val))[dat$val]
      out <- dat
         
      # create meesages # 2 300
      if( length(unique(streamdataAcc$cognitoId)) > 2 &&
            dim(streamdataAcc)[1] > 300){
        
        if( exists("alarmMotion") ){
          for(a in alarmMotion){
            closeAlert(session, paste("motion", alarmMotion, sep="-"))
          }
        }
        
        alarmMotion <- c()
        x <- boxplot.stats(streamdataAcc$x, coef=7)
        for(i in x$out){
          id <- which(streamdataAcc$x==i)
          alarmMotion <- append(alarmMotion, streamdataAcc[id,]$cognitoId)
        }
        y <- boxplot.stats(streamdataAcc$y)
        for(i in y$out){
          id <- which(streamdataAcc$y==i)
          alarmMotion <- append(alarmMotion, streamdataAcc[id,]$cognitoId)
        }
        z <- boxplot.stats(streamdataAcc$z)
        for(i in z$out){
          id <- which(streamdataAcc$z==i)
          alarmMotion <- append(alarmMotion, streamdataAcc[id,]$cognitoId)
        }
        alarmMotion <- unique( alarmMotion )
        for( a in alarmMotion){
          #createAlert(session, inputId = "alert_anchor",
          #            alertId = paste("motion", alarmMotion, sep="-"),
          #            message = paste("Device Motion Warning for", alarmOrientation),
          #            type = "warning",dismiss = TRUE,block = FALSE,append = TRUE)
        }
      }
      
    }
    out
  })
  devMotionBoxplot %>% 
        ggvis(x = ~coord, 
              y = ~val) %>%
         layer_boxplots(coef=7) %>%
         add_axis("x", title = "") %>%
         set_options(height=150, width=NULL) %>%
         bind_shiny("devMotionBoxplot") 
  
   freefallData <- reactive({
     newstreamdata <- getMotionData()
     if(dim(newstreamdata)[1] == 0) {
         value <- data.frame(ip = character(), recordTime = integer(),
                             cognitoId = character(),
                             device = character(), sensorname = character(),
                             sumxyz = numeric(),
                             stringsAsFactors=FALSE)
      } else {
         value <- newstreamdata %>% 
              filter(sensorname=="screenAccG") %>%
              mutate(sumxyz=round(x)+round(y)+round(z)) 
      }
     value
   })
   freefallData %>% ggvis(x = ~recordTime, 
                         y = ~sumxyz, 
                         stroke = ~cognitoId) %>%
       layer_lines()  %>%
       hide_axis("x") %>%
       add_axis("y", title = "x+y+z") %>%
       set_options(height=100, width=NULL) %>% 
       bind_shiny("freefallPlot") 
  
  
  varianceAllData <- reactive({ 
     streamdata <- getMotionData()
     if(dim(streamdata)[1] == 0) {
       value <- data.frame(cognitoId = "",
                           varx = 0, vary = 0, varz = 0,
                           stringsAsFactors=FALSE)
     } else {
       value <- streamdata %>% 
         filter(sensorname=="screenAccG") %>%
         summarise(varx=var(x), vary=var(y), varz=var(z))
     }
     value
   })
  varianceNewData <- reactive({
    newstreamdata <- getNewMotionData()
    varall <- varianceAllData()
    if(dim(newstreamdata)[1] == 0) {
      value <- data.frame(cognitoId = "",
                          varx = 0, vary = 0, varz = 0,
                          varallx=0,varally=0,varallz=0,
                          stringsAsFactors=FALSE)
    } else {
      value <- newstreamdata %>% 
          filter(sensorname=="screenAccG") %>%
          group_by(cognitoId) %>% 
          summarise(varx=var(x), vary=var(y), varz=var(z))
      value <- cbind(value, varallx=varall$varx, varally=varall$vary, varallz=varall$varz)
    }   
    value
  })
  varianceNewData %>% 
       ggvis(x=~cognitoId, y=~varx) %>%
       layer_points(y=~varx, fill = "x") %>%
       layer_points(y=~vary, fill = "y") %>%
       layer_points(y=~varz, fill = "z") %>%
       layer_lines(y=~varallx, stroke = "x") %>%
       layer_lines(y=~varally, stroke = "y") %>%
       layer_lines(y=~varallz, stroke = "z") %>%
       hide_axis("x") %>%
       add_axis("y", title = "varianz") %>%
       add_legend("fill") %>%
       set_options(height=100, width=NULL) %>% 
       bind_shiny("variancePlot") 


  #######################
  # BOXES
  # Nr devices
  output$nrdevices <- renderUI({
    newstreamdata <- getNewOrientationData()
    if(dim(newstreamdata)[1] == 0) {
      value <- 0
    } else {
      value <- length(unique(newstreamdata$cognitoId))
    }
    valueBox(
            value = value,
            subtitle = "Total Devices",
            icon = icon("mobile"),
            width = NULL,
            color = if (value == 0) "yellow" else "aqua"
    )
  })
  
  # Nr reads per sec 
  output$nrreadssecs <- renderUI({
    newstreamdata <- getNewOrientationData()
    if(dim(newstreamdata)[1] == 0) {
      value <- "no data"
    } else {
        secs <- as.integer(input$refresh)
        nr <- dim(newstreamdata)[1] * 3 / secs # three different data sources
        if(nr < 0.5) nr <- 1
        value <- formatC(nr, digits = 0, format = "f")
    }
    valueBox(
          value = value,
          subtitle = "Number of Reads per sec",
          icon = icon("sign-out"),
          width = NULL,
          color = if (value == "no data") "yellow" else "aqua"
    )
  
  })
  
  # MB reads per sec
  output$MBreadssecs <- renderUI({
      newstreamdata <- getNewOrientationData()
      if(dim(newstreamdata)[1] == 0) {
        value <- "no data"
      } else {
        secs <- as.integer(input$refresh)
        nr <- format( (3*object.size(newstreamdata))/secs, units="Kb")
        value <- formatC(nr, digits = 1, format = "f")
      }
      valueBox(
        value = value,
        subtitle = "Reads per sec",
        icon = icon("sign-out"),
        width = NULL,
        color = if (value == "no data") "yellow" else "aqua"
      )
    
  })
  
  # min realtime delay
  output$deltaT <- renderUI({
    newstreamdata <- getNewOrientationData()
    if(dim(newstreamdata)[1] == 0) {
      dt <- 0
      value <- "no data"
    } else {
      dt <- as.numeric(Sys.time()) - max(newstreamdata$recordTime, na.rm = TRUE)
      value <- formatC(dt, digits = 2, format = "f")
    }

    valueBox(
      value = value,
      subtitle = "min Real-time delay in secs",
      icon = icon("clock-o"),
      color = if (dt >= 60 || dt == 0) "yellow" else "aqua",
      width = NULL
    )
  })
  
  # realtime delay avg
  output$deltaTavg <- renderUI({
    newstreamdata <- getNewOrientationData()
    if(dim(newstreamdata)[1] == 0) {
      dt <- 0
      value <- "no data"
    } else {
      topnTimes <- newstreamdata %>% group_by(cognitoId) %>% top_n(n=2,wt=recordTime)
      dt <- as.numeric(Sys.time()) - mean(topnTimes$recordTime, na.rm = TRUE)
      value <- formatC(dt, digits = 2, format = "f")
    }
    
    valueBox(
      value = value,
      subtitle = "Avg. Real-time delay in secs",
      icon = icon("clock-o"),
      color = if (dt >= 60 || dt == 0) "yellow" else "aqua",
      width = NULL
    )
  })
  
  ###############
  # Navbar Menues
  # header bar messages
  output$dropdownMenu <- renderUI({
    messageData <- newDataAlarms()
    
   if(dim(messageData)[1]>0){
        # msgs for navbar
        msgs <- apply(messageData, 1, function(row) {
              if( row["status"]!="NA" ){ # no dependency to viz !!
                  return(notificationItem(text = row[["text"]], 
                               status = row[["status"]]))
              }
        })  
        # msg for page
        assign("messageData", messageData, env=.GlobalEnv)
        apply(messageData, 1, function(row) {
              if(row["viz"]==0 && row["status"]!="NA"){
                createAlert(session, "alert_anchor", 
                            alertId = as.character(row["cognitoId"]), 
                            content = as.character(row["text"]), 
                            style = 'warning',
                            dismiss = TRUE, append = TRUE)
                createAlert(session, "alert_anchor2", 
                            alertId = as.character(row["cognitoId"]), 
                            content = as.character(row["text"]), 
                            style = 'warning',
                            dismiss = TRUE, append = TRUE)
              }
        })
        messageData$viz <- 1
        messageData <<- messageData
    } else {
      msgs <- NULL
    }
    dropdownMenu(type = "notifications", .list = msgs)
  })
  
  
  #######################
  # Data Simulation
  output$simOut <- reactive({
    # Take a dependency on input$startSim
    buttonvalue <- input$startSim
    
    if( buttonvalue != 0){  
      system(
        paste("python data_sim/SensorLogGenerator.py", 
              input$simtime,
              input$simnrdevices,
              input$sendtime,
              "data_sim/data/cleanSimData_Motion.csv",
              "data_sim/data/cleanSimData_Orientation.csv",
              "data_sim/data/cleanSimData_Geo.csv"
        ), wait = FALSE, ignore.stdout = TRUE)
      out <- "Simulation started ..."
    } else {
      out <- ""
    }
    out
  })
  
}
