####################################################################################################
##dataPrepration.R: this script fills missing values in the data
####################################################################################################
dataPreparation = function(outputDir,region,startTime,endTime)
{
  #create hadoop server data sources
  inputDS = RxTextData(file = inputDir, missingValueString = "M", fileSystem = hdfsFS)  
  rxDataStep(inData = edfDataDS, 
             outFile = inputDS, 
             rowSelection = (region == 101),
             overwrite = TRUE)
  #outputDS = RxTextData(file = outputDir, fileSystem = hdfsFS)  
  
  #fill NA values in the data
  #outputFile = rxExec(fillNA,inData = inputDS)
  outputFile = fillNA(inData = inputDS)
  
  #load data from local csv back to hadoop
  rxHadoopMakeDir(outputDir)
  rxHadoopCopyFromLocal(outputFile, outputDir)
  outputDS = RxTextData(file = outputDir, missingValueString = "M", fileSystem = hdfsFS)  
  return(outputDS)
}

fillNA = function (inData)
{	
  
  #Convert input data into data frame
  data=rxImport(inData)
  
  #Create full time series by filling in missing timestamps
  data$utcTimestamp = as.POSIXlt(data$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S")
  minTime=min(data$utcTimestamp)
  maxTime=max(data$utcTimestamp)
  resolution = difftime("2015-11-01 05:00:00 UTC", "2015-11-01 04:00:00 UTC")
  fullTime = seq(from=minTime, to=maxTime, by=resolution)
  fullTimedf = data.frame(utcTimestamp = fullTime)
  fullTimedf$utcTimestamp=as.character(fullTimedf$utcTimestamp)
  data$utcTimestamp=as.character(data$utcTimestamp)
  newdata = merge(fullTimedf, data, by.x = 'utcTimestamp',by.y = 'utcTimestamp', all=TRUE)
  
  # fill in missing value based on previous day same hour's Load
  for (i in 25:nrow(newdata)){
    if (is.na(newdata$Load[i])) 
    {newdata$Load[i] = newdata$Load[i-24]}
  }
  for (i in 25:nrow(newdata)){
    if (is.na(newdata$temperature[i])) 
    {newdata$temperature[i] = newdata$temperature[i-24]}
  }
  
  # method 1: write data to local csv
  write.table(newdata, file="Data/newdata.csv", sep=",", row.names=FALSE)
  outputFile = file.path(wd,"Data","newdata.csv")
  return(outputFile)
  
  # method 2: write data to hadoop data source
  #newdataDir <- "/user/RevoShare/azureuser/newdata"
  #rxHadoopMakeDir(newdataDir)
  #newdataXdf <- RxXdfData(newdataDir, fileSystem=hdfsFS)
  #rxImport(inData=newdata, outFile=newdataXdf, overwrite=TRUE)
  #rxDataStep(inData=newdataXdf, outFile=outData, overwrite=TRUE)
  ##ERROR: rxDataStep cannot write xdf file to csv in hdfs
}

#timeConversion = function(dataList){
  #dataList[["utcTimestamp"]]<-as.POSIXlt(dataList$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S")
#  dataList$utcTimestamp<-strptime(dataList$utcTimestamp, tz="GMT", format="%Y-%m-%d %H:%M:%S")
#  return(data)
#}