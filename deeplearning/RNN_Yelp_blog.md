Yelp\_GRU\_blog
================
Yue Qi
May 31, 2018

``` r
knitr::opts_chunk$set()
```

Import SWAT Package
-------------------

``` r
library("swat")
```

    ## NOTE: The extension module for binary protocol support is not available.

    ##       Only the CAS REST interface can be used.

    ## SWAT 1.2.0.9000

Connect to CAS Server and Load CAS Actionsets
---------------------------------------------

``` r
conn = CAS('rdcgrd001.unx.sas.com', port = 8777)
```

    ## NOTE: Connecting to CAS and generating CAS action functions for loaded

    ##       action sets...

    ## NOTE: To generate the functions with signatures (for tab completion), set

    ##       options(cas.gen.function.sig=TRUE).

``` r
cas.sessionProp.setSessOpt(conn, caslib='HPS')
```

    ## NOTE: 'HPS' is now the active caslib.

    ## list()

``` r
loadActionSet(conn, 'deepLearn')
```

    ## NOTE: Added action set 'deepLearn'.

    ## NOTE: Information for action set 'deepLearn':

    ## NOTE:    deepLearn

    ## NOTE:       buildModel - Creates an empty deep learning model

    ## NOTE:       addLayer - Adds a layer to a deep learning model

    ## NOTE:       removeLayer - Removes a layer from a deep learning model

    ## NOTE:       dlPrune - Prune a layer in a deep learning model

    ## NOTE:       modelInfo - Shows model information

    ## NOTE:       dlTune - Tunes hyperparameters for deep learning model

    ## NOTE:       dlTrain - Trains a deep learning model

    ## NOTE:       dlScore - Scores a table using a deep learning model

    ## NOTE:       dlExportModel - Exports a deep learning model

    ## NOTE:       dlLabelTarget - Assigns the target label information

    ## NOTE:       dlImportModelWeights - Imports model weights from an external source

    ## NOTE:       dlJoin - Joins the data table and annotation table

Load Data Sets - Training Data, Validation Data, and Test Data
--------------------------------------------------------------

``` r
out <- cas.table.loadTable(conn, path = 'yelp_review_train.sashdat',
                           casout = list(replace = TRUE))
```

    ## NOTE: Cloud Analytic Services made the HDFS file yelp_review_train.sashdat available as table YELP_REVIEW_TRAIN in caslib HPS.

``` r
train <- defCasTable(conn, out$tableName)
out <- cas.table.loadTable(conn, path = 'yelp_review_val.sashdat', 
                           casout = list(replace = TRUE))
```

    ## NOTE: Cloud Analytic Services made the HDFS file yelp_review_val.sashdat available as table YELP_REVIEW_VAL in caslib HPS.

``` r
val <- defCasTable(conn, out$tableName)
out <- cas.table.loadTable(conn, path = 'yelp_review_test.sashdat', 
                           casout = list(replace = TRUE))
```

    ## NOTE: Cloud Analytic Services made the HDFS file yelp_review_test.sashdat available as table YELP_REVIEW_TEST in caslib HPS.

``` r
test <- defCasTable(conn, out$tableName)
```

``` r
cas.table.tableInfo(conn)
```

    ## $TableInfo
    ##                Name   Rows Columns IndexedColumns Encoding
    ## 1 YELP_REVIEW_TRAIN 179892       2              0  wlatin1
    ## 2   YELP_REVIEW_VAL  22437       2              0  wlatin1
    ## 3  YELP_REVIEW_TEST  22643       2              0  wlatin1
    ##         CreateTimeFormatted          ModTimeFormatted
    ## 1 2018-05-31T15:02:44-04:00 2018-05-31T15:02:44-04:00
    ## 2 2018-05-31T15:02:57-04:00 2018-05-31T15:02:57-04:00
    ## 3 2018-05-31T15:03:10-04:00 2018-05-31T15:03:10-04:00
    ##         AccessTimeFormatted JavaCharSet CreateTime    ModTime AccessTime
    ## 1 2018-05-31T15:02:44-04:00      Cp1252 1843412564 1843412564 1843412564
    ## 2 2018-05-31T15:02:57-04:00      Cp1252 1843412577 1843412577 1843412577
    ## 3 2018-05-31T15:03:10-04:00      Cp1252 1843412590 1843412590 1843412590
    ##   Global Repeated View                SourceName SourceCaslib Compressed
    ## 1      0        0    0 yelp_review_train.sashdat          HPS          0
    ## 2      0        0    0   yelp_review_val.sashdat          HPS          0
    ## 3      0        0    0  yelp_review_test.sashdat          HPS          0
    ##   Creator Modifier    SourceModTimeFormatted SourceModTime
    ## 1  sasyqi          2018-05-11T10:42:31-04:00    1841668951
    ## 2  sasyqi          2018-05-11T10:42:42-04:00    1841668962
    ## 3  sasyqi          2018-05-11T10:43:00-04:00    1841668980

What's in the Table
-------------------

``` r
out <- cas.table.fetch(train, to = 5)
outDF = out$Fetch
print(outDF, right = F)
```

    ##   _Index_
    ## 1 1      
    ## 2 2      
    ## 3 3      
    ## 4 4      
    ## 5 5      
    ##   review                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
    ## 1 I love Marilo!  She understands my hair type and knows exactly what to do with my hair.  She keeps a record of my previous visits.  She recommends what is best for my hair.  She is pleasant to work with: easygoing, friendly, and respectful.  I've been going to her since 2008.  I'm really picky with hair people, and I used to go back to Chicago for haircuts.  Now, I stick to Marilo.                                                                                                                                                                                       
    ## 2 I had lunch here today. I love the owner, he is awesome. Always friendly and he tries so hard to make everyone happy. I had the raw beef pho and it was very good. Not the best I've had but definitely up there. I also had the spring rolls. A little too much mint for my liking but they were fresh. All of the veggies were beautiful. Fresh and lots of flavor. My beef was pretty good too. The fat had been trimmed completely so I was thrilled. I hate fat. It hit the spot with me and I will continue to go back. The service is great and fast. Overall a nice experience.
    ## 3 All baristas are not created equal. The crew at Seattle Espresso knows how to pull shots. They've got the best iced mocha in town. They splash Illy with heavy cream. Definitely worth driving to S. Tempe for!                                                                                                                                                                                                                                                                                                                                                                        
    ## 4 Service okay. I always receive bad service from a certain drive thru lady. I don't know if it's just towards me or not.                                                                                                                                                                                                                                                                                                                                                                                                                                                                
    ## 5 There is nothing like riding your cruiser to La Grande Orange on a Sat or Sun. This is a great place to listen to the music and people watch, while enjoying a nice breakfast, salad, sandwich, pizza, coffee or glass of sangria. It's usually busy, but fairly laid-back. Grab today's paper, bring your laptop and enjoy the ambiance. The big draw-back is the parking.                                                                                                                                                                                                            
    ##   sentiment
    ## 1 positive 
    ## 2 positive 
    ## 3 positive 
    ## 4 negative 
    ## 5 positive

Load Word Encoding Files
------------------------

``` r
# GloVe: Global Vectors for Word Representation. GloVe is an unsupervised learning algorithm for obtaining vector 
# representations for words. Training is performed on aggregated global word-word co-occurrence statistics from a corpus, 
# and the resulting representations showcase interesting linear substructures of the word vector space.


out <- cas.table.loadTable(conn, path = 'glove_100d_tab_clean.sashdat', 
                           casout = list(name = "glove",replace = TRUE))
```

    ## NOTE: Cloud Analytic Services made the HDFS file glove_100d_tab_clean.sashdat available as table GLOVE in caslib HPS.

Building a Gated Recurrent Unit Model Architecture
--------------------------------------------------

``` r
# Sentiment classification
# In this example, GRU model is used as specified by the option "rnnType". You can specify other layer types "LSTM" and "RNN".
# In some layers, reverse = True is specified, and that makes GRU bi-directional. Specifically, layers rnn11 and rnn 21 
# are in the reverse direction, which means the model scan the sentence from the end to the beginning, while rnn12 and rnn22 are
# in the common forward direction. Therefore, the state of a neuron is not only affected by the previous words, but also the 
# words after the neuron.

n=64
init='msra'

cas.deepLearn.buildModel(conn, model=list(name='sentiment', replace=TRUE), type='RNN')
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment    1       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='data', layer=list(type='input'))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   11       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='rnn11', srclayers=list('data'),
  layer=list(type='recurrent',n=n,init=init,rnnType='GRU',
             outputType='samelength', reverse=TRUE))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   26       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='rnn12', srclayers=list('data'),
  layer=list(type='recurrent',n=n,init=init,rnnType='GRU',
             outputType='samelength', reverse=FALSE))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   41       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='rnn21', srclayers=list('rnn11', 'rnn12'),
  layer=list(type='recurrent',n=n,init=init,rnnType='GRU',
             outputType='samelength', reverse=TRUE))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   57       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='rnn22', srclayers=list('rnn11', 'rnn12'),
  layer=list(type='recurrent',n=n,init=init,rnnType='GRU',
             outputType='samelength', reverse=FALSE))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   73       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='rnn3', srclayers=list('rnn21', 'rnn22'),
  layer=list(type='recurrent',n=n,init=init,rnnType='GRU',
             outputType='encoding'))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment   89       5

``` r
cas.deepLearn.addLayer(conn,
  model='sentiment', name='outlayer', srclayers=list('rnn3'),
           layer=list(type='output'))
```

    ## $OutputCasTables
    ##   casLib      Name Rows Columns
    ## 1    HPS sentiment  102       5

Training the Model
------------------

``` r
cas.deepLearn.dlTrain(conn,
  table=train, model='sentiment', validtable=val,
  modelWeights=list(name='sentiment_trainedWeights', replace=TRUE),
  textParms=list(initEmbeddings='glove', hasInputTermIds=FALSE, embeddingTrainable=FALSE),
  target='sentiment', 
  inputs='review',
  texts='review', 
  nominals='sentiment',
  optimizer=list(miniBatchSize=4, maxEpochs=20, 
                 algorithm=list(method='adam', beta1=0.9, beta2=0.999, gamma=0.5,
                                learningRate=0.0005,clipGradMax=100, clipGradMin=-100,
                                stepSize=20, lrPolicy='step')
                 ),
  seed=12345
)
```

    ## $ModelInfo
    ##                                        Descr                    Value
    ## 1                                 Model Name                sentiment
    ## 2                                 Model Type Recurrent Neural Network
    ## 3                           Number of Layers                        7
    ## 4                     Number of Input Layers                        1
    ## 5                    Number of Output Layers                        1
    ## 6             Number of Convolutional Layers                        0
    ## 7                   Number of Pooling Layers                        0
    ## 8           Number of Fully Connected Layers                        0
    ## 9                 Number of Recurrent Layers                        5
    ## 10               Number of Weight Parameters                   173696
    ## 11                 Number of Bias Parameters                      962
    ## 12          Total Number of Model Parameters                   174658
    ## 13 Approximate Memory Cost for Training (MB)                      419
    ## 
    ## $OptIterHistory
    ##    Epoch LearningRate       Loss   FitError ValidLoss ValidError
    ## 1      0        5e-04 0.36773245 0.15269161 0.2143324 0.08915815
    ## 2      1        5e-04 0.20051248 0.08158228 0.1750559 0.07242970
    ## 3      2        5e-04 0.17251026 0.06958620 0.1588009 0.06307080
    ## 4      3        5e-04 0.15726042 0.06300447 0.1477583 0.05873045
    ## 5      4        5e-04 0.14609423 0.05824606 0.1395813 0.05637942
    ## 6      5        5e-04 0.13769993 0.05437707 0.1356244 0.05362148
    ## 7      6        5e-04 0.13057713 0.05124742 0.1381576 0.05443530
    ## 8      7        5e-04 0.12598489 0.04970204 0.1310325 0.05140609
    ## 9      8        5e-04 0.11932448 0.04671692 0.1292415 0.05032101
    ## 10     9        5e-04 0.11463890 0.04458786 0.1271427 0.04932634
    ## 11    10        5e-04 0.11039062 0.04276455 0.1239757 0.04769871
    ## 12    11        5e-04 0.10638311 0.04102461 0.1203175 0.04589023
    ## 13    12        5e-04 0.10259873 0.03955707 0.1176084 0.04412696
    ## 14    13        5e-04 0.09901221 0.03781713 0.1160645 0.04376526
    ## 15    14        5e-04 0.09558879 0.03642185 0.1153973 0.04344877
    ## 16    15        5e-04 0.09229719 0.03498766 0.1153324 0.04240890
    ## 17    16        5e-04 0.08913303 0.03370356 0.1154703 0.04249932
    ## 18    17        5e-04 0.08611803 0.03253063 0.1152957 0.04195678
    ## 19    18        5e-04 0.08336753 0.03145220 0.1139348 0.04191157
    ## 20    19        5e-04 0.08138976 0.03086852 0.1119409 0.04141423
    ## 
    ## $OutputCasTables
    ##   casLib                     Name   Rows Columns
    ## 1    HPS sentiment_trainedWeights 174658       3

``` r
cas.table.save(table='sentiment_trainedWeights', caslib='casuser',
               name='demo_review_sentiment_trainedweights.sashdat', replace=TRUE,
               saveAttrs = TRUE)
```

    ## list()

Scoring Test Data
-----------------

``` r
cas.deepLearn.dlScore(
  table=test, model='sentiment', initWeights='sentiment_trainedWeights',
  copyVars=list('review', 'sentiment'), textParms=list(initInputEmbeddings='glove'),
  casout=list(name='sentiment_out', replace=TRUE)
  )
```

    ## $OutputCasTables
    ##   casLib          Name  Rows Columns
    ## 1    HPS sentiment_out 22643       7
    ## 
    ## $ScoreInfo
    ##                         Descr        Value
    ## 1 Number of Observations Read        22643
    ## 2 Number of Observations Used        22643
    ## 3 Misclassification Error (%)     4.186724
    ## 4                  Loss Error     0.109483
