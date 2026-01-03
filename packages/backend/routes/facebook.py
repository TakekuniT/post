import os
import requests
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from utils.db_client import UserManager

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
async def facebook_login():
    """
    Step 1: Redirect the user to the Facebook Login Dialog.
    """
    scope_str = ",".join(SCOPES)
    auth_url = (
        f"https://www.facebook.com/v19.0/dialog/oauth?"
        f"client_id={CLIENT_ID}&"
        f"redirect_uri={REDIRECT_URI}&"
        f"scope={scope_str}&"
        f"response_type=code"
    )
    return RedirectResponse(auth_url)

@router.get("/callback")
async def facebook_callback(request: Request, code: str):
    """
    Step 2: Handle the callback, exchange code for tokens, 
    and link Page/Instagram accounts.
    """
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

        # 2. Exchange for Long-Lived User Token (60 days)
        ll_url = "https://graph.facebook.com/v19.0/oauth/access_token"
        ll_params = {
            "grant_type": "fb_exchange_token",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "fb_exchange_token": short_token
        }
        ll_res = requests.get(ll_url, params=ll_params).json()
        user_access_token = ll_res["access_token"]

        # 3. Get the list of Pages and their linked Instagram Business IDs
        # We need the Page Access Token to post Reels to Facebook
        accounts_url = "https://graph.facebook.com/v19.0/me/accounts"
        accounts_res = requests.get(accounts_url, params={
            "fields": "name,access_token,instagram_business_account",
            "access_token": user_access_token
        }).json()

        # # 4. Save each Page and its associated Instagram account
        # for page in accounts_res.get("data", []):
        #     # Save Facebook Page Account
        #     UserManager.save_social_account(user_id, "facebook", {
        #         "access_token": page["access_token"], # Page Token never expires if user token is LL
        #         "page_id": page["id"],
        #         "name": page["name"],
        #         "expires_at": "2099-01-01T00:00:00" # Page tokens are essentially permanent
        #     })
            
        #     # Save Instagram Account if linked to this page
        #     if "instagram_business_account" in page:
        #         ig_id = page["instagram_business_account"]["id"]
        #         UserManager.save_social_account(user_id, "instagram", {
        #             "access_token": page["access_token"], # Instagram uses the Page Token
        #             "instagram_business_id": ig_id,
        #             "name": f"IG: {page['name']}",
        #             "expires_at": "2099-01-01T00:00:00"
        #         })
        pages_list = []

        if "data" in accounts_res:
            for page in accounts_res["data"]:
                # Extract the key info for each page
                page_info = {
                    "facebook_id": page.get("id"),
                    "access_token": page.get("access_token"),
                    "name": page.get("name"),
                    # Include IG ID if it exists
                    # "instagram_business_id": page.get("instagram_business_account", {}).get("id")
                }
                pages_list.append(page_info)

        return {
            "status": "success",
            "token_data": pages_list 
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))