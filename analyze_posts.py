import json
import datetime
from pprint import pprint
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from urllib.parse import urlparse
import scipy.stats

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
        tld = domain.split('.')[-1]
        if tld == 'fi':
            domain = '.'.join(domain.split('.')[-2:])
        else:
            domain = None
    d = {
            'date': pd.to_datetime(post['time']),
            'poster_id': post['user_id'],
            'post_id': post['post_id'],
            'reactions': post['likes'],
            'link': post['link'],
            'comments': post['comments'],
            'domain': domain
    }
    
    data.append(d)

data = pd.DataFrame.from_records(data)
data = data.sort_values('date').reset_index()

posters = data.groupby('poster_id')
postercounts = posters['post_id'].count().values
bins = np.arange(1, 100)
plt.hist(posters['post_id'].count(), bins=bins)

plt.ylabel("Henkilöä")
plt.xlabel("Henkilön tekemää avausta")
plt.loglog()

plt.figure()

perday = data.groupby(pd.Grouper(freq='W', key='date'))['post_id'].count()

plt.ylabel("Avauksia päivässä")
plt.xlabel("Päivä")

data = data.dropna()
print(len(data))
domains = data.groupby('domain')
is_popular = [k for k, v in (domains['post_id'].count() > 10).iteritems() if v]
domains = data[data.domain.isin(is_popular)].groupby('domain')
domainscount = domains['comments'].mean()
with pd.option_context('display.max_rows', None, 'display.max_columns', None):
    print(domainscount.sort_values()[::-1][:100])

plt.figure()

print(scipy.stats.spearmanr(data['reactions']+1, data['comments']+1))
plt.loglog()
plt.show()
#print(data)
