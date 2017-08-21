####################################################################################################
##trainModel.R: this function trains a random regression forest model
####################################################################################################
trainModel = function(trainDataDir, test.length)
{
  trainDataDS = RxTextData(file = trainDataDir, fileSystem = hdfsFS)  
  rxDataStep(inData = allFeaturesDS, 
             outFile = trainDataDS, 
             numRows = 35040-test.length,
             removeMissings = TRUE,
             overwrite = TRUE)

  #create training formula
  labelVar = "Load"
  featureVars = rxGetVarNames(trainDataDS)
  featureVars = featureVars[which((featureVars!=labelVar)&(featureVars!="region")&(featureVars!="utcTimestamp"))]
  formula = as.formula(paste(paste(labelVar,"~"),paste(featureVars,collapse="+")))
  
  #train regression forest model 
  #model = rxDForest(formula, data = trainDataDS)	
  model=rxLinMod(formula, data=trainDataDS)
  return(model)
}

