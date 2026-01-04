import os
import requests
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from utils.db_client import UserManager
from urllib.parse import urlencode
router = APIRouter()

# --- CONFIGURATION ---
CLIENT_ID = os.getenv("FACEBOOK_CLIENT_ID")
CLIENT_SECRET = os.getenv("FACEBOOK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("FACEBOOK_REDIRECT_URI")

# Combined scopes for both Facebook Reels and Instagram Reels
SCOPES = [
    "public_profile",
    "email",
    "pages_show_list",
    "pages_read_engagement",
    "pages_manage_posts",
    "publish_video",
    "instagram_basic",
    "instagram_content_publish"
]

@router.get("/")
def test_facebook():
    return {"message": "Facebook route is working"}

@router.get("/login")
async def facebook_login(user_id: str):
    auth_url = "https://www.facebook.com/v19.0/dialog/oauth"

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": ",".join(SCOPES),
        "response_type": "code",
        "state": user_id,  
    }

    return RedirectResponse(url=f"{auth_url}?{urlencode(params)}")
    

@router.get("/callback")
async def facebook_callback(request: Request, code: str, state: str):
    user_id = state 
    try:
        # 1. Exchange Code for Short-Lived Access Token
        token_url = "https://graph.facebook.com/v19.0/oauth/access_token"
        token_params = {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "redirect_uri": REDIRECT_URI,
            "code": code
        }
        res = requests.get(token_url, params=token_params).json()
        short_token = res.get("access_token")
        
        if not short_token:
            raise HTTPException(status_code=400, detail=f"Token exchange failed: {res}")

        # 2. Exchange for Long-Lived User Token (~60 days)
        ll_url = "https://graph.facebook.com/v19.0/oauth/access_token"
        ll_params = {
            "grant_type": "fb_exchange_token",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "fb_exchange_token": short_token
        }
        ll_res = requests.get(ll_url, params=ll_params).json()
        user_access_token = ll_res.get("access_token")

        # 3. Get Pages (and linked IG accounts)
        accounts_url = "https://graph.facebook.com/v19.0/me/accounts"
        accounts_res = requests.get(accounts_url, params={
            "fields": "name,access_token,instagram_business_account",
            "access_token": user_access_token
        }).json()

        saved_accounts = []

        if "data" in accounts_res:
            for page in accounts_res["data"]:
                page_id = page.get("id")
                page_name = page.get("name")
                page_token = page.get("access_token")

                # A. Save Facebook Page
                # Matches: (user_id, platform, access_token, refresh_token, expires_at, platform_user_id)
                UserManager.save_social_account(
                    user_id,
                    "facebook",
                    page_token,
                    None,  # No refresh token for FB
                    "2099-01-01T00:00:00",
                    page_id
                )
                saved_accounts.append({"type": "facebook", "name": page_name})

                # B. Save Instagram Business Account if linked
                # ig_business = page.get("instagram_business_account")
                # if ig_business:
                #     ig_id = ig_business.get("id")
                #     UserManager.save_social_account(
                #         user_id,
                #         "instagram",
                #         page_token, # IG uses the Page Access Token
                #         None,
                #         "2099-01-01T00:00:00",
                #         ig_id
                #     )
                #     saved_accounts.append({"type": "instagram", "name": f"IG: {page_name}"})

        return {
            "status": "success",
            "message": f"Successfully connected {len(saved_accounts)} accounts",
            "accounts": saved_accounts
        }

    except Exception as e:
        print(f"Error in FB Callback: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))