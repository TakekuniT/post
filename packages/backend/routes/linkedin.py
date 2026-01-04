import os
import requests
import time
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from utils.db_client import UserManager
from urllib.parse import urlencode

router = APIRouter()

# --- CONFIGURATION ---
CLIENT_ID = os.getenv("LINKEDIN_CLIENT_ID")
CLIENT_SECRET = os.getenv("LINKEDIN_CLIENT_SECRET")
REDIRECT_URI = os.getenv("LINKEDIN_REDIRECT_URI")
APP_REDIRECT_URI = os.getenv("APP_REDIRECT_URI")

# Scopes for Profile access and Video/Post publishing
SCOPES = [
    "openid",
    "profile",
    "email",
    "w_member_social"  # Permission to post on behalf of the user
]

@router.get("/")
def test_linkedin():
    return {"message": "LinkedIn route is working"}

@router.get("/login")
async def linkedin_login(user_id: str):
    auth_url = "https://www.linkedin.com/oauth/v2/authorization"

    params = {
        "response_type": "code",
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "state": user_id,  # Passing our internal Supabase user_id
        "scope": " ".join(SCOPES), # LinkedIn uses space-separated scopes
    }

    return RedirectResponse(url=f"{auth_url}?{urlencode(params)}")

@router.get("/callback")
async def linkedin_callback(request: Request, code: str, state: str):
    user_id = state 
    try:
        # 1. Exchange Code for Access Token
        token_url = "https://www.linkedin.com/oauth/v2/accessToken"
        token_data = {
            "grant_type": "authorization_code",
            "code": code,
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "redirect_uri": REDIRECT_URI
        }
        
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        res = requests.post(token_url, data=token_data, headers=headers).json()
        
        access_token = res.get("access_token")
        expires_in = res.get("expires_in", 5184000) # Defaults to ~60 days

        if not access_token:
            raise HTTPException(status_code=400, detail=f"Token exchange failed: {res}")

        # 2. Get Member ID (LinkedIn URN)
        # We need the 'sub' field (Member ID) to identify who is posting
        user_info_url = "https://api.linkedin.com/v2/userinfo"
        user_info = requests.get(user_info_url, headers={
            "Authorization": f"Bearer {access_token}"
        }).json()

        linkedin_id = user_info.get("sub") # This is the unique Member ID
        user_name = f"{user_info.get('given_name')} {user_info.get('family_name')}"

        # 3. Save to Supabase via UserManager
        # LinkedIn tokens are typically long-lived but do expire
        UserManager.save_social_account(
            user_id,
            "linkedin",
            access_token,
            None,  # LinkedIn doesn't always provide a refresh token for member_social
            expires_in, # Or calculate expires_at using 'expires_in'
            linkedin_id
        )

        print(f"Successfully connected LinkedIn for {user_name}")
        return RedirectResponse(f"{APP_REDIRECT_URI}?platform=linkedin")

    except Exception as e:
        print(f"Error in LinkedIn Callback: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))