# install.sh pipes this into the transmute container.
# Makes the one user that convert.lab signs you in as, with the password from .env.
import json
import os
import sys
import urllib.error
import urllib.request

API = "http://localhost:3313/api/users"
USER = {"username": "me", "password": os.environ["TRANSMUTE_PASSWORD"]}


def post(url, body):
    req = urllib.request.Request(
        url, json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    return urllib.request.urlopen(req, timeout=10)


with urllib.request.urlopen(API + "/bootstrap-status", timeout=10) as res:
    if json.load(res)["requires_setup"]:
        post(API, {**USER, "role": "member", "disabled": False})  # first user is admin

try:
    post(API + "/authenticate", USER)
except urllib.error.HTTPError as err:
    sys.exit(f"can't sign in as me ({err.code}): was the user made with another password?")
