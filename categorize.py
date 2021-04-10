import re
import yaml
import json
from urllib.parse import urlparse
from collections import defaultdict
import requests
requests.packages.urllib3.util.ssl_.DEFAULT_CIPHERS = 'ALL:@SECLEVEL=1'
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
import requests_cache



publication_types = ('press_release', 'article', 'story')
institution_types = ('private', 'journal', 'university', 'go', 'ngo', 'personal')
interest_types = ('public', 'political', 'business', 'labour', 'special')

categories = {
    'publication': publication_types,
    'institution': institution_types,
    'interest': interest_types
        }

categorization = yaml.load(open("categories.yaml"))
session = requests_cache.CachedSession("post_links_cache")


def get_tag_category(tag):
    for category, types in categories.items():
        if tag in types: return category

    raise KeyError(f"No category for tag '{tag}'")

def structure_categories(catstring):
    cats = {}
    if not catstring: return cats
    tags = catstring.split()
    for tag in tags:
        cat = get_tag_category(tag)
        if cat in cats:
            raise KeyError(f"Duplicate category '{cat}' in '{catstring}'")
        cats[cat] = tag
    return cats

def get_categories(url):
    if not url: return {}, None
    """
    try:
        content = session.get(url, verify=False)
    except Exception as e:
        print("Fetch failed:", e)
    """
    domain = str(urlparse(url).netloc)
    domain = "." + domain # Hack
    for trial, cats in categorization.items():
        if domain.endswith(trial):
            domain = trial
            cats = structure_categories(cats)
            return cats, domain
    return {}, domain

def find_uncategorized():
    data = (json.loads(l) for l in open("posts.jsons"))
    missing_per_domain = defaultdict(list)
    for row in data:
        url = row['link']
        if url is None: continue
        cats = get_categories(url)
        if cats: continue
        domain = str(urlparse(url).netloc)
        missing_per_domain[domain].append(url)

    for domain, urls in sorted(missing_per_domain.items(), key=lambda i: len(i[1])):
        print(len(urls), domain)

if __name__ == "__main__":
    find_uncategorized()
