from fastapi import APIRouter, Query
from fastapi.responses import RedirectResponse, JSONResponse
import requests
import os
import urllib.parse

router = APIRouter()

CLIENT_ID = os.environ.get("INSTAGRAM_CLIENT_ID")
CLIENT_SECRET = os.environ.get("INSTAGRAM_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("INSTAGRAM_REDIRECT_URI")
SCOPES = [
    "instagram_basic",           # Replaces user_profile
    "instagram_content_publish", # Allows you to post
    "pages_read_engagement",     # Needed to see the linked IG account
    "pages_show_list"            # Needed to find the Facebook Page linked to IG
]

@router.get("/")
def test_instagram():
    return {"message": "Instagram route is working"}

@router.get("/login")
def instagram_login():
    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": ",".join(SCOPES),
        "response_type": "code",
    }
    #auth_url = "https://api.instagram.com/oauth/authorize?" + urllib.parse.urlencode(auth_params)
    auth_url = "https://www.facebook.com/v18.0/dialog/oauth?" + urllib.parse.urlencode(auth_params)
    return RedirectResponse(auth_url)

@router.get("/callback")
def instagram_callback(code: str = None):
    if not code:
        return JSONResponse({"error": "No code provided"}, status_code=400)
    # token_url = "https://api.instagram.com/oauth/access_token"
    token_url = "https://graph.facebook.com/v18.0/oauth/access_token"
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
        "code": code
    }
    response = requests.post(token_url, data=data)
    if response.status_code != 200:
        return {"error": response.json()}
    tokens = response.json()
    return tokens


