import json
import datetime
from pprint import pprint
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from urllib.parse import urlparse
import scipy.stats
from categorize import get_categories
import sys

posts = [json.loads(r) for r in open("posts.jsons")]

data = []
ids = set()
for post in posts:
    if post['post_id'] in ids: continue
    ids.add(post['post_id'])
    domain = post['link']
    if domain is not None:
        domain = urlparse(domain).netloc
        domain = domain.split(':')[0]
    
    cats = get_categories(post['link'])

    d = {
            'date': pd.to_datetime(post['time']),
            'poster_id': post['user_id'],
            'post_id': post['post_id'],
            'reactions': post['likes'],
            'link': post['link'],
            'comments': post['comments'],
            'domain': domain,
            'shares': post['shares'],
            'share_id': post['shared_post_id'],
            'has_images': bool(post['images']),
            'video_id': post['video_id']
    }

    for cat, tag in cats.items():
        d[cat] = tag
    
    data.append(d)

data = pd.DataFrame.from_records(data)
data = data.sort_values('date')#.reset_index()

data.to_csv("posts.csv", index=False)


