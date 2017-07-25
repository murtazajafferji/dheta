import os

from miro.client import MiroClient
from miro import utils

import pandas as pd
import numpy as np

csv_file = 'labeled_data.csv'
data_dir = ''

def get_data():

    from sklearn.preprocessing import Imputer, LabelEncoder
    from sklearn.feature_extraction.text import CountVectorizer

    df = pd.DataFrame()
    df = pd.concat([df, pd.read_csv(utils.pj(data_dir, csv_file), delimiter=",")], axis=0)

    test_set_start = df.shape[0]

    # these aren't needed
    #df.pop("COMMENT_ID")
    #df.pop("AUTHOR")
    #df.pop("DATE")

    target_variable = 'class'

    y = df.pop(target_variable).values
    y = LabelEncoder().fit_transform(y).reshape(y.shape[0], 1)

    # featurize as bag-of-words
    vectorizer = CountVectorizer()
    X = vectorizer.fit_transform(df['tweet'].values)
    X = X.todense()

    num_classes = np.unique(y).shape[0]

    return X, y, num_classes, test_set_start


def run():
    X, y, num_classes, test_set_start = get_data()

    X, X_test = X[:test_set_start], X[test_set_start:]
    y, y_test = y[:test_set_start], y[test_set_start:]
    client = MiroClient(
        'https://automl.corp.microsoft.com:1337',
        api_key=ENV['MIRO_API_KEY'],
        max_time_sec=250,
    )
    final_pipeline = client.fit(X, y,
                                frac_valid=0.25,
                                iterations=25,
                                num_classes=num_classes)
    print(final_pipeline)
    print("test set score", client.score(X_test, y_test))

run()