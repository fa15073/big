####################################################################################################
##mainRhdp.R: this is the main R script of the Energy Demand Forecasting template
####################################################################################################

####################################################################################################
##Settings
#In order to run this script, you need to set the values of the parameters in this section to your
#own values. 
####################################################################################################

#Set working directory. Please change this to the main directory of the template
wd <- "/home/azureuser/edfcastRhdpDemo"

####################################################################################################	
#Source function scripts.
####################################################################################################
source(file.path(wd,"R","dataPreparationRhdp.R"))
source(file.path(wd,"R","featureEngineeringRhdp.R"))
source(file.path(wd,"R","trainModelRhdp.R"))

####################################################################################################	
#Set up HadoopMR compute context. 
####################################################################################################
rxHadoopMakeDir("/user/RevoShare/azureuser") 
rxHadoopCommand("fs -chmod uog+rwx /user/RevoShare/azureuser") 

bigDataDirRoot <- "/share" 
myHadoopCluster <- RxHadoopMR() 

################################################################################################
## Data Ingestion
################################################################################################
rxSetComputeContext('local')
demand <- read.table("Data/DemandHistory15Minutes.txt", header=TRUE, sep="\t")
temp <- read.table("Data/TemperatureHistoryHourly.txt", header=TRUE, sep="\t")
edfData <- merge(demand, temp, by=c("utcTimestamp", "region"))
write.table(edfData, file="Data/DemandTemp.csv", sep=",", row.names=FALSE)

####################################################################################################
#load data into Hadoop.
####################################################################################################
#Switch to HadoopMR compute context. From now on, all the executions will be done in the Hadoop cluster
rxSetComputeContext(myHadoopCluster) 
edfDataFile <- file.path(wd,"Data","DemandTemp.csv")
edfDataDir <- file.path(bigDataDirRoot, "edfDataSample")
rxHadoopMakeDir(edfDataDir)
rxHadoopCopyFromLocal(edfDataFile, edfDataDir)
hdfsFS <- RxHdfsFileSystem() 
edfDataDS <- RxTextData(file = edfDataDir, missingValueString = "M", fileSystem = hdfsFS)  
rxGetInfo(edfDataDS, getVarInfo=TRUE, numRows=3)

####################################################################################################
##Data preperation and feature engineering
####################################################################################################

#Set region and time frame
region <- 101
startTime <- "2015-01-01 00:00:00"
#scoreStartTime <- "2015-12-31 00:00:00"
endTime <- "2015-12-31 23:45:00"

#Hadoop data source names
inputDir <- file.path(bigDataDirRoot, paste("edfData",region,sep="")) 
filledNADir <- file.path(bigDataDirRoot, paste("edfNAfilled",region,sep="")) 
basicFeaturesDir <- file.path(bigDataDirRoot, paste("edfBasicFeatures",region,sep=""))
allFeaturesDir <- file.path(bigDataDirRoot, paste("edfAllFeatures",region,sep=""))
trainDataDir <- file.path(bigDataDirRoot, paste("edfTrainData",region,sep=""))
predictionDir <- file.path(bigDataDirRoot, paste("edfPrediction",region,sep=""))

#Data preparation. Join demand and temperature table, and fill NA values.
filledNADS <- dataPreparation(filledNADir, region, startTime, endTime)
rxGetInfo(filledNADS, getVarInfo=TRUE, numRows=3)

#Feature engineering. Compute basic features and lagging features
allFeaturesDS <- featureEngineering(filledNADir,basicFeaturesDir,allFeaturesDir)
rxGetInfo(allFeaturesDS, getVarInfo=TRUE, numRows=3)

####################################################################################################	
##Train model
####################################################################################################
test.length <- 24
model <- trainModel(trainDataDir, test.length)
model

####################################################################################################
##Score model
####################################################################################################
#scoreDataDir <- file.path(bigDataDirRoot, paste("edfScoreData",region,sep=""))
#scoreDataDS <- RxTextData(file = scoreDataDir, fileSystem = hdfsFS)  
#scoreDataDf <- rxDataStep(inData = allFeaturesDS, 
#           #outFile = scoreDataDS, 
#           startRow = 35040-test.length+1,
#           numRows = test.length,
#           overwrite = TRUE) # startRow does not work
rxSetComputeContext("local")
allFeaturesDf <- read.csv(file="Data/data.csv", header=TRUE, sep=",")
scoreDataDf <- tail(allFeaturesDf, n=test.length)
write.table(scoreDataDf, file="Data/scoreData.csv", sep=",", row.names=FALSE)
rxSetComputeContext(myHadoopCluster) 
scoreDataFile <- file.path(wd,"Data","scoreData.csv")
scoreDataDir <- file.path(bigDataDirRoot, paste("edfScoreData",region,sep=""))
rxHadoopMakeDir(scoreDataDir)
rxHadoopCopyFromLocal(scoreDataFile, scoreDataDir)
hdfsFS <- RxHdfsFileSystem() 
scoreDataDS <- RxTextData(file = scoreDataDir, fileSystem = hdfsFS)  
predictionXdf <- RxXdfData(predictionDir, fileSystem = hdfsFS)  
rxPredict(model, data=scoreDataDS, outData=predictionXdf, extraVarsToWrite=c("utcTimestamp","Load"), overwrite=TRUE)
rxGetInfo(predictionXdf, getVarInfo=TRUE, numRows=3)

####################################################################################################	
##model evaluation, compute MAPE (mean absolute percent error)
####################################################################################################
predictionDf <- rxImport(predictionXdf)
result <- data.frame(utcTimestamp=predictionDf$utcTimestamp, 
                     Load=predictionDf$Load, 
                     Load_Pred=predictionDf$Load_Pred)
result[complete.case(result),]

MAPE <- mean(abs(result$Load_Pred - result$Load)/result$Load, na.rm=TRUE)
MAPE
print(paste("The mean absolute percent error is ",MAPE, sep=""))