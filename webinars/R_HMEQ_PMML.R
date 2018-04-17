# Get data
hmeq<-read.csv('http://support.sas.com/documentation/onlinedoc/viya/exampledatasets/hmeq.csv')

# Classify categorical variables
hmeq$BAD<-as.factor(hmeq$BAD)
hmeq$REASON<-as.factor(hmeq$REASON)
hmeq$JOB<-as.factor(hmeq$JOB)

# Build decision tree
library(rpart)
hmeq_r<-rpart(BAD ~ LOAN + MORTDUE + VALUE + REASON + JOB + YOJ + DEROG + DELINQ + CLAGE + NINQ + CLNO + DEBTINC, data = hmeq, method = 'class')

# Convert to PMML
library(pmml)
sink(file = 'R_HMEQ.xml')
pmml(hmeq_r)
sink()