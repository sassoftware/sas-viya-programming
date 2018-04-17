##############################
##### DO NOT TOUCH BELOW #####
##############################

# Import packages and start CAS session
import swat, sys
conn = swat.CAS()

table = sys.argv[1]
nodeid = sys.argv[2]
caslib = sys.argv[3]

# Bring data locally
df = conn.CASTable(caslib = caslib, name = table).to_frame()

##############################
##### DO NOT TOUCH ABOVE #####
##############################

# Import packages
import pandas as pd
from sklearn.preprocessing import Imputer
from sklearn.ensemble import GradientBoostingClassifier

#############
# Data prep #
#############

### Modify pandas dataframe called df ###

# Impute missing values
## Most frequent
df['IMP_REASON']=df['REASON'].fillna('DebtCon')
df['IMP_JOB']=df['JOB'].fillna('Other')
## Mean
mean_imp = Imputer(missing_values='NaN', strategy='mean', axis=0)
mean=pd.DataFrame(mean_imp.fit_transform(df[['CLAGE','MORTDUE','NINQ','DEROG']]), columns=['IMP_CLAGE','IMP_MORTDUE','IMP_NINQ','IMP_DEROG'])
## Median
median_imp = Imputer(missing_values='NaN', strategy='most_frequent', axis=0)
median = pd.DataFrame(median_imp.fit_transform(df[['DELINQ','VALUE','CLNO','DEBTINC','YOJ']]), columns=['IMP_DELINQ','IMP_VALUE','IMP_CLNO','IMP_DEBTINC','IMP_YOJ'])
## Bring together
df=pd.concat([df[['_dmIndex_', '_PartInd_', 'BAD', 'LOAN']], df.iloc[:,-2:], mean, median], axis=1)

# One-hot encode character variables
dtypes = df.dtypes
nominals = dtypes[dtypes=='object'].keys().tolist()
df = pd.concat([df, pd.get_dummies(df[nominals])], axis = 1).drop(nominals, axis = 1)

##################
# Model building #
##################

# Inputs for prediction
X = df.iloc[:,3:]

# Training inputs
train = df[df['_PartInd_'] == 1]
X_train = train.iloc[:,3:]
y_train = train.iloc[:,2]

# Gradient Boosting classifier
model = GradientBoostingClassifier()
model.fit(X_train, y_train)

################################################
#### Follow Pattern Below for Binary Target ####
################################################

### Modify pandas dataframe called df ###

# Predict 
pred = model.predict_proba(X)

# Create new columns on original dataset
target = 'BAD'
df['P_' + target + '1'] = pred[:,1]
df['P_' + target + '0'] = pred[:,0]

##############################
##### DO NOT TOUCH BELOW #####
##############################

# Upload results
conn.upload_frame(df, casout = dict(name = nodeid + '_score', caslib = caslib, promote = True))

##############################
##### DO NOT TOUCH ABOVE #####
##############################

