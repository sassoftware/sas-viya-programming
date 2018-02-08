# Fashion-MNIST
Using SAS deepLearn API to classify apparel
## Notebooks and file descriptions 
This repository contains a series of notebooks to get you up and running in the SAS deep learning framework, deepLearn. 
1. The fashion_mnist notebook documents how to build a LeNet style CNN to categorize the contents of the Fashion MNIST dataset. 
2. The fashion_mnist_dataprep notebook creates image files from the 'original' Fashion MNIST CSV files. 
3. The casplt.py file is a convenience function for plotting images originating from a CASTable. 
## Data 
[Dataset from Kaggle](https://www.kaggle.com/zalando-research/fashionmnist)
## Benchmark 
Some rough performance results on Fashion MNIST dataset

| Classifier | Preprocessing | Fashion test accuracy | MNIST test accuracy | Submitter| Code |
| --- | --- | --- | --- | --- |--- |
|2 Conv Layers + max pooling and 1 FC ~3M parameters | standard preprocessing (mean/std subtraction/division) | 0.923 | - | [Ben Sloane](https://github.com/bensloane) | [:link:](https://github.com/bensloane/fashion-mnist/blob/master/fashion_mnist.ipynb) |
