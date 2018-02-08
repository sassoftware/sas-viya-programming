import pandas as pd
import matplotlib
import numpy as np
import matplotlib.pyplot as plt

def plot_imgs(cas_table, class_list=range(10), images_per_class=2, figsize=(20,20), query_condition=None, font_size=12):
    """Function for plotting image data from a CASTable object"""
    
    class_description = {'class0':'T-shirt/top', 'class1':'Trouser', 'class2':'Pullover', 'class3':'Dress', 'class4':'Coat',
                     'class5':'Sandal', 'class6':'Shirt', 'class7':'Sneaker', 'class8':'Bag', 'class9':'Ankle boot'}
    
    img_list=[]
    lbl_list=[]
    prd_list=[]
    arr_list=[]
    
    if len(class_list) < images_per_class:
        fig, axes = plt.subplots(nrows=len(class_list), ncols=images_per_class, figsize=figsize)
        
    else:
        fig, axes = plt.subplots(nrows=images_per_class, ncols=len(class_list), figsize=figsize)

    for i in class_list:
        a = cas_table.groupby(['_label_']).get_group(['class'+str(i)]).query(query_condition)
        b = a.sample(images_per_class).fetch(to=images_per_class)
        lbl_list.append((b['Fetch']['_label_']))
        img_list.append((b['Fetch']['_image_']))

        if query_condition != None:
            prd_list.append((b['Fetch']['_DL_PredName_']))
    
    
    img_df=pd.concat(img_list)
    lbl_df=pd.concat(lbl_list)
    
    if query_condition != None:
        prd_df=pd.concat(prd_list)
    

    for j in img_df:
        c=np.fromstring(j,np.uint8)
        c=c.reshape((28,28))
        arr_list.append(c)
    
    for x,ax in enumerate(axes.flat):
        ax.imshow(arr_list[x],cmap='gray')
        ax.set_title('True label: {}'.format(class_description[lbl_df.iloc[x]]))
        ax.title.set_fontsize(font_size)
        ax.xaxis.label.set_fontsize(font_size)

        if query_condition != None:
            ax.set_xlabel('Pred label: {}'.format(class_description[prd_df.iloc[x]]))
            
        ax.set_xticks([])
        ax.set_yticks([])
        plt.tight_layout()