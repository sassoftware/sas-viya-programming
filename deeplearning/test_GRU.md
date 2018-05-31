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
conn = CAS('rdcgrd001.unx.sas.com', port = 41776)
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
#out <- cas.table.loadTable(conn, path = 'yelp_review_val.sashdat', 
#                           casout = list(replace = TRUE))
#val <- defCasTable(conn, out$tableName)
#out <- cas.table.loadTable(conn, path = 'yelp_review_test.sashdat', 
#                           casout = list(replace = TRUE))
#test <- defCasTable(conn, out$tableName)
cas.table.tableInfo(conn)
```

    ## $TableInfo
    ##                Name   Rows Columns IndexedColumns Encoding
    ## 1 YELP_REVIEW_TRAIN 179892       2              0  wlatin1
    ##         CreateTimeFormatted          ModTimeFormatted
    ## 1 2018-05-31T14:35:40-04:00 2018-05-31T14:35:40-04:00
    ##         AccessTimeFormatted JavaCharSet CreateTime    ModTime AccessTime
    ## 1 2018-05-31T14:35:40-04:00      Cp1252 1843410940 1843410940 1843410940
    ##   Global Repeated View                SourceName SourceCaslib Compressed
    ## 1      0        0    0 yelp_review_train.sashdat          HPS          0
    ##   Creator Modifier    SourceModTimeFormatted SourceModTime
    ## 1  sasyqi          2018-05-11T10:42:31-04:00    1841668951

``` r
cas.table.tableInfo(conn)
```

    ## $TableInfo
    ##                Name   Rows Columns IndexedColumns Encoding
    ## 1 YELP_REVIEW_TRAIN 179892       2              0  wlatin1
    ##         CreateTimeFormatted          ModTimeFormatted
    ## 1 2018-05-31T14:35:40-04:00 2018-05-31T14:35:40-04:00
    ##         AccessTimeFormatted JavaCharSet CreateTime    ModTime AccessTime
    ## 1 2018-05-31T14:35:40-04:00      Cp1252 1843410940 1843410940 1843410940
    ##   Global Repeated View                SourceName SourceCaslib Compressed
    ## 1      0        0    0 yelp_review_train.sashdat          HPS          0
    ##   Creator Modifier    SourceModTimeFormatted SourceModTime
    ## 1  sasyqi          2018-05-11T10:42:31-04:00    1841668951

What's in the Table
-------------------

``` r
head(train)
```
<div align="left">

    ##                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    review
    ## 1                                                                                                                                                                                        I love Marilo!  She understands my hair type and knows exactly what to do with my hair.  She keeps a record of my previous visits.  She recommends what is best for my hair.  She is pleasant to work with: easygoing, friendly, and respectful.  I've been going to her since 2008.  I'm really picky with hair people, and I used to go back to Chicago for haircuts.  Now, I stick to Marilo.
    ## 2 I had lunch here today. I love the owner, he is awesome. Always friendly and he tries so hard to make everyone happy. I had the raw beef pho and it was very good. Not the best I've had but definitely up there. I also had the spring rolls. A little too much mint for my liking but they were fresh. All of the veggies were beautiful. Fresh and lots of flavor. My beef was pretty good too. The fat had been trimmed completely so I was thrilled. I hate fat. It hit the spot with me and I will continue to go back. The service is great and fast. Overall a nice experience.
    ## 3                                                                                                                                                                                                                                                                                                                                                                         All baristas are not created equal. The crew at Seattle Espresso knows how to pull shots. They've got the best iced mocha in town. They splash Illy with heavy cream. Definitely worth driving to S. Tempe for!
    ## 4                                                                                                                                                                                                                                                                                                                                                                                                                                                                 Service okay. I always receive bad service from a certain drive thru lady. I don't know if it's just towards me or not.
    ## 5                                                                                                                                                                                                             There is nothing like riding your cruiser to La Grande Orange on a Sat or Sun. This is a great place to listen to the music and people watch, while enjoying a nice breakfast, salad, sandwich, pizza, coffee or glass of sangria. It's usually busy, but fairly laid-back. Grab today's paper, bring your laptop and enjoy the ambiance. The big draw-back is the parking.
    ## 6                    There are way to many amazing places to go to Bandera.  When calling in to make a reservation I was informed "they don't do that" when asked what their corkage fee was.  The place had a normal busy Saturday night crowd but it seemed there staff was not trained for that.  We had multiple servers where we had to ask for menu's, silverware, drinks & plates. At one point even stopping a cook._x000D_\r\n_x000D_\r\nThe food was ehh and no I would not go back.  Because like I said before there are way to many amazing places in the valley to go here.
    ##   sentiment
    ## 1  positive
    ## 2  positive
    ## 3  positive
    ## 4  negative
    ## 5  positive
    ## 6  negative
</div>

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
