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