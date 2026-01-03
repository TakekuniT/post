import os
import requests
from fastapi import APIRouter, Request, Form, File, UploadFile, BackgroundTasks, Response
from fastapi.responses import RedirectResponse
from utils.oauth import OAuthManager
from models.user import UserManager
from urllib.parse import quote

router = APIRouter()
oauth = OAuthManager()


@router.get("/")
def test_tiktok():
    return {"message": "TikTok route is working"}

@router.get("/login")
def tiktok_login():
    verifier, challenge = oauth.generate_pkce_pair()
    
    auth_url = (
        f"https://www.tiktok.com/v2/auth/authorize/"
        f"?client_key={os.getenv('TIKTOK_CLIENT_ID')}"
        f"&scope=user.info.basic,video.upload,video.publish"
        f"&response_type=code"
        f"&redirect_uri={os.getenv('TIKTOK_REDIRECT_URI')}"
        f"&code_challenge={challenge}"
        f"&code_challenge_method=S256"
        f"&state={verifier}"
    )
    return RedirectResponse(auth_url)

@router.get("/callback")
async def tiktok_callback(code: str, state: str):
    # Now we get the verifier directly from the URL!
    token_data = oauth.exchange_tiktok_code(code, state)
    
    if "access_token" in token_data:
        return {"status": "success", "token": token_data["access_token"][:10]}
    
    return {"status": "error", "details": token_data}