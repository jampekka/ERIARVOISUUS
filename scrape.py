from facebook_scraper import get_posts
from pprint import pprint
import json
import datetime

def myconverter(o):
    if isinstance(o, datetime.datetime):
        return o.__str__()

for post in get_posts(group="485003524967015", pages=1000, timeout=60, extra_info=True):
    print(json.dumps(post, default=myconverter))
