from fastapi import APIRouter
from fastapi.responses import RedirectResponse
import os
import urllib.parse

router = APIRouter()

CLIENT_ID = os.environ.get("INSTAGRAM_CLIENT_ID")
CLIENT_SECRET = os.environ.get("INSTAGRAM_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("INSTAGRAM_REDIRECT_URI")
SCOPES = ["user_profile", "user_media", "instagram_content_publish"]

@router.get("/")
def test_instagram():
    return {"message": "Instagram route is working"}

@router.get("/login")
def instagram_login():
    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": " ".join(SCOPES),
        "response_type": "code",
    }
    auth_url = "https://api.instagram.com/oauth/authorize?" + urllib.parse.urlencode(auth_params)
    return RedirectResponse(auth_url)

