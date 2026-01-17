import os
import requests
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from utils.db_client import UserManager
from urllib.parse import urlencode
import json
from jose import jwt, jwk
from dotenv import load_dotenv
from utils.limiter import limiter

load_dotenv()
router = APIRouter()

# --- CONFIGURATION ---
CLIENT_ID = os.getenv("THREADS_CLIENT_ID")
CLIENT_SECRET = os.getenv("THREADS_CLIENT_SECRET")
REDIRECT_URI = os.getenv("THREADS_REDIRECT_URI")
APP_REDIRECT_URI = os.getenv("APP_REDIRECT_URI")

# Decode Supabase Public Key for JWT verification
jwk_dict = json.loads(os.getenv("SUPABASE_JWK_SECRET"))
actual_key = jwk_dict["keys"][0]
public_key = jwk.construct(actual_key, algorithm="ES256")

# Minimum scopes for Threads publishing
SCOPES = [
    "threads_basic",
    "threads_content_publish"
]

@router.get("/login")
@limiter.limit("10/minute")
async def threads_login(request: Request, token: str):
    try:
        payload = jwt.decode(
            token, 
            public_key, 
            algorithms=["ES256"], 
            audience="authenticated"
        )
        verified_user_id = payload.get("sub")
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")
    
    # Threads uses a different OAuth dialog URL
    auth_url = "https://www.threads.net/oauth/authorize"

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": ",".join(SCOPES),
        "response_type": "code",
        "state": verified_user_id,
    }

    return RedirectResponse(url=f"{auth_url}?{urlencode(params)}")

@router.get("/callback")
@limiter.limit("10/minute")
async def threads_callback(request: Request, code: str, state: str):
    user_id = state 
    try:
        # 1. Exchange Code for Short-Lived Access Token
        # NOTE: Threads uses graph.threads.net, not graph.facebook.com
        token_url = "https://graph.threads.net/oauth/access_token"
        token_data = {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "grant_type": "authorization_code",
            "redirect_uri": REDIRECT_URI,
            "code": code
        }
        
        res = requests.post(token_url, data=token_data).json()
        short_token = res.get("access_token")
        threads_user_id = res.get("user_id") # Threads gives user_id directly here
        
        if not short_token:
            raise HTTPException(status_code=400, detail=f"Threads Token exchange failed: {res}")

        # 2. Exchange for Long-Lived Token (~60 days)
        ll_url = "https://graph.threads.net/access_token"
        ll_params = {
            "grant_type": "th_exchange_token",
            "client_secret": CLIENT_SECRET,
            "access_token": short_token
        }
        ll_res = requests.get(ll_url, params=ll_params).json()
        long_lived_token = ll_res.get("access_token")

        if not long_lived_token:
             raise HTTPException(status_code=400, detail="Failed to get long-lived token")

        # 3. Get Threads Profile Info (optional, to get username)
        me_url = "https://graph.threads.net/v1.0/me"
        me_res = requests.get(me_url, params={
            "fields": "id,username",
            "access_token": long_lived_token
        }).json()

        # 4. Save to Database
        # Matches: (user_id, platform, access_token, refresh_token, expires_at, platform_user_id)
        UserManager.save_social_account(
            user_id,
            "threads",
            long_lived_token,
            None, # Threads tokens are refreshed via the LL token itself, not a separate refresh token
            "2099-01-01T00:00:00", # Or calculate 60 days from now
            threads_user_id
        )

        return RedirectResponse(f"{APP_REDIRECT_URI}?platform=threads")

    except Exception as e:
        print(f"Error in Threads Callback: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))