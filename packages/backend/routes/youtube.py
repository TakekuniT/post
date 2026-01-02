from fastapi import APIRouter
from fastapi.responses import RedirectResponse
import os
import urllib.parse
import requests


router = APIRouter()

CLIENT_ID = os.environ.get("YOUTUBE_CLIENT_ID")
CLIENT_SECRET = os.environ.get("YOUTUBE_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("YOUTUBE_REDIRECT_URI")
SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]

@router.get("/")
def test_youtube():
    return {"message": "Youtube route is working"}