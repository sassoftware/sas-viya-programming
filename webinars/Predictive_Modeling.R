# 
# Copyright SAS Institute 
# 
#  Licensed under the Apache License, Version 2.0 (the License); 
#  you may not use this file except in compliance with the License. 
#  You may obtain a copy of the License at 
# 
#      http://www.apache.org/licenses/LICENSE-2.0 
# 
#  Unless required by applicable law or agreed to in writing, software 
#  distributed under the License is distributed on an "AS IS" BASIS, 
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
#  See the License for the specific language governing permissions and 
#  limitations under the License. 
# 


# Loading the required SWAT package and other R libraries necessary
library(swat)
library(ggplot2)
library(reshape2)
library(xgboost)
library(caret)
library(dplyr)
library(pROC)
library(e1071)
library(ROCR)
library(pmml)
library(randomForest)
library(caret) 

# Connect to CAS server using appropriate credentials 

s = CAS()

# Create a CAS library called lg pointing to the defined directory
# Need to specify the srctype as path, otherwise it defaults to HDFS

cas.table.addCaslib(s,
                    name = "lg",
                    description = "Looking glass data",
                    dataSource = list(srcType="path"),
                    path = "/viyafiles/tmp"
)

# Load the data into the in-memory CAS server

data = cas.read.csv(s, 
                    "C:/Users/Looking_glass.csv", 
                    casOut=list(name="castbl", caslib="lg", replace=TRUE) 
)

# Invoke the overloaded R functions to view the head and summary of the input table

print(head(data))
print(summary(data))

# Check for any missingness in the data 

dist_tabl = cas.simple.distinct(data)$Distinct[,c('Column','NMiss')]
print(dist_tabl)
dist_tabl = as.data.frame(dist_tabl)
sub = subset(dist_tabl, dist_tabl$NMiss != 0)
imp_cols = sub$Column

# Print the names of the columns to be imputed 
print(imp_cols)

# Impute the missing values 

cas.dataPreprocess.impute(data,
                          methodContinuous = 'MEDIAN',
                          methodNominal    = 'MODE',
                          inputs           = imp_cols,
                          copyAllVars      = TRUE,
                          casOut           = list(name = 'castbl', replace = TRUE)
)

# Split the data into training and validation and view the partitioned table

loadActionSet(s,"sampling")

cas.sampling.srs( s,
                  table   = list(name="castbl", caslib="lg"),
                  samppct = 30,
                  seed = 123456,
                  partind = TRUE,
                  output  = list(casOut = list(name = "sampled_castbl", replace = T, caslib="lg"), copyVars = 'ALL')
)

# Check for frequency distribution of partitioned data

cas.simple.freq(s,table="sampled_castbl", inputs="_PartInd_")

# Partition data into train and validation based on _PartInd_

train = defCasTable(s, tablename = "sampled_castbl", where = " _PartInd_ = 0 ")

val   = defCasTable(s, tablename = "sampled_castbl", where = " _PartInd_ = 1 ")

# Create the appropriate input and target variables

info = cas.table.columnInfo(s, table = train)

colinfo = info$ColumnInfo

## nominal variables are: region, upsell_xsell

nominals = colinfo$Column[c(7,8)]

intervals = colinfo$Column[c(-7,-8,-9,-15,-18)]

target = colinfo$Column[8]

inputs = colinfo$Column[c(-8,-9,-15,-18)]

# Build a GB model for predictive classification

loadActionSet(s, "decisionTree")

model = cas.decisionTree.gbtreeTrain(
  s,
  casOut=list(caslib="lg",name="gb_model",replace=T), 
  saveState = list(caslib="lg", name="R_SWAT_GB", replace=T),
  inputs = inputs,
  nominals = nominals, 
  target = target,
  table = train
)

# View the model info

print(model)

cas.table.promote(s, caslib="lg", name="R_SWAT_GB", targetCaslib="casuser")

# Score the model on test data

out = cas.decisionTree.gbtreeScore ( 
  s,                                        
  modelTable = list(name="gb_model", caslib="lg"),
  table = val,
  encodeName = TRUE, 
  assessonerow = TRUE,
  casOut = list(name="scored_data", caslib="lg", replace=T),
  copyVars = target
)

# View the scored results

cas.table.fetch(s,table="scored_data")

# Train an R eXtreme Gradient Boosting model

# First, convert the train and test CAS tables to R data frames for training the R-XGB model
train_cas_df = to.casDataFrame(train)
train_df = to.data.frame(train_cas_df)

val_cas_df = to.casDataFrame(val)
val_df = to.data.frame(val_cas_df)

# In R, we need to do the data pre-processing explicitly. Hence, convert the "char" region variable to "factor"

train_df$upsell_xsell = as.factor(train_df$upsell_xsell)
val_df$upsell_xsell = as.factor(val_df$upsell_xsell)

train_df$days_openwrkorders = train_df$IMP_days_openwrkorders
train_df$ever_days_over_plan = train_df$IMP_ever_days_over_plan

val_df$days_openwrkorders = val_df$IMP_days_openwrkorders
val_df$ever_days_over_plan = val_df$IMP_ever_days_over_plan

train_df$IMP_days_openwrkorders = NULL
train_df$IMP_ever_days_over_plan = NULL

val_df$IMP_days_openwrkorders = NULL
val_df$IMP_ever_days_over_plan = NULL


# Train a RF model on the data 

rf_model <- randomForest(upsell_xsell ~ . , ntree=2, mtry=5, data=train_df[,c(3,8,9,10,11,12,14)], importance=TRUE)

# Make predictions on test data

pred <- predict(rf_model, val_df[,c(3,8,9,10,11,12,14)], type="prob")

# Evaluate the performance of SAS and R models

## Assessing the performance metric of SAS-GB model

loadActionSet(s,"percentile")

tmp = cas.percentile.assess( 
  s,                                                   
  cutStep = 0.05,
  event = "1", 
  inputs = "P_upsell_xsell1",
  nBins = 20,
  response = target,
  table = "scored_data" 
  
)$ROCInfo

roc_df = data.frame(tmp)
print(head(roc_df))

# Display the confusion matrix for cutoff threshold at 0.5

cutoff = subset(roc_df, CutOff == 0.5)

tn = cutoff$TN
fn = cutoff$FN
tp = cutoff$TP
fp = cutoff$FP
a = c(tn,fn)
p = c(fp,tp)
mat = data.frame(a,p)
colnames(mat) = c("Pred:0","Pred:1")
rownames(mat) = c("Actual:0","Actual:1")
mat = as.matrix(mat)
print(mat)

# Print the accuracy and misclassification rates for the model

accuracy = cutoff$ACC
mis = cutoff$MISCEVENT

print(paste("Misclassification rate is",mis))

print(paste("Accuracy is",accuracy))

## Assessing the performance metric of R-RF model

# Create a confusion matrix for cutoff threshold at 0.5

conf.matrix = table(val_df$upsell_xsell, as.numeric(pred[,2]>0.5))
rownames(conf.matrix) = paste("Actual", rownames(conf.matrix), sep = ":")
colnames(conf.matrix) = paste("Pred", colnames(conf.matrix), sep = ":")

# Print the accuracy and misclassification rates for the model

err = mean(as.numeric(pred[,2] > 0.5) != val_df$upsell_xsell)

print(paste("Misclassification rate is",err))

print(paste("Accuracy is",1-err))

# Plot ROC curves for both the models using standard R plotting functions

FPR_SAS = roc_df['FPR']
TPR_SAS = roc_df['Sensitivity']

pred1 = prediction(pred[,2], test_labels)
perf1 = performance( pred1, "tpr", "fpr" )

FPR_R = perf1@x.values[[1]]
TPR_R = perf1@y.values[[1]]

roc_df2 = data.frame(FPR = FPR_R, TPR = TPR_R)

ggplot() + 
  
  geom_line(
    data = roc_df[c('FPR', 'Sensitivity')], 
    aes(x = as.numeric(FPR), y = as.numeric(Sensitivity),color = "SAS"),
  ) +
  
  geom_line(
    data = roc_df2, 
    aes(x = as.numeric(FPR_R), y = as.numeric(TPR_R),color = "R_RF"), 
  ) +
  
  scale_color_manual(
    name = "Colors", 
    values = c("SAS" = "blue", "R_RF" = "red")
  ) +
  
  xlab('False Positive Rate') + ylab('True Positive Rate')

# Generating PMML code to export R model to Model Manager

rf.pmml = pmml(rf_model)
format(object.size(rf.pmml))
savePMML(rf.pmml, "C:/Users/neveng/rf.xml", version=4.2 )

# Terminate the CAS session

cas.session.endSession(s)
