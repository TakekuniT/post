import os
import requests
from fastapi import APIRouter, Request, Form, File, UploadFile, BackgroundTasks, Response, HTTPException
from fastapi.responses import RedirectResponse
from utils.oauth import OAuthManager
from urllib.parse import quote
import datetime
from utils.db_client import UserManager
from jose import jwt, jwk # from python-jose
from dotenv import load_dotenv
import json
from utils.limiter import limiter

load_dotenv()

router = APIRouter()
oauth = OAuthManager()

APP_REDIRECT_URI = os.getenv("APP_REDIRECT_URI")

jwk_dict = json.loads(os.getenv("SUPABASE_JWK_SECRET"))
actual_key = jwk_dict["keys"][0]
public_key = jwk.construct(actual_key, algorithm="ES256")

@router.get("/")
def test_tiktok():
    return {"message": "TikTok route is working"}

@router.get("/login")
@limiter.limit("10/minute")
def tiktok_login(request: Request, token: str):
    # 1. Generate PKCE pair
    verifier, challenge = oauth.generate_pkce_pair()

    try:
        # Re-use our secure decoding logic
        payload = jwt.decode(
            token, 
            public_key, 
            algorithms=["ES256"], 
            audience="authenticated"
        )
        verified_user_id = payload.get("sub")
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")
    
    
    # 2. We need to store both the verifier AND the user_id. 
    # A common way is to combine them in the state (e.g., "verifier:user_id")
    #state_payload = f"{verifier}:{user_id}"
    state_payload = f"{verifier}:{verified_user_id}"

    auth_url = (
        f"https://www.tiktok.com/v2/auth/authorize/"
        f"?client_key={os.getenv('TIKTOK_CLIENT_ID')}"
        f"&scope=user.info.basic,video.upload,video.publish"
        f"&response_type=code"
        f"&redirect_uri={os.getenv('TIKTOK_REDIRECT_URI')}"
        f"&code_challenge={challenge}"
        f"&code_challenge_method=S256"
        f"&state={state_payload}"
    )
    return RedirectResponse(auth_url)

@router.get("/callback")
@limiter.limit("10/minute")
async def tiktok_callback(request: Request, code: str, state: str):
    try:
        # 1. Deconstruct the state to get the verifier and user_id
        if ":" not in state:
            raise HTTPException(status_code=400, detail="Invalid state parameter")
        
        verifier, user_id = state.split(":", 1)

        # 2. Exchange code for tokens (TikTok requires the verifier/state here)
        token_data = oauth.exchange_tiktok_code(code, verifier)
        
        if "access_token" not in token_data:
            return {"status": "error", "details": token_data}

        # 3. Calculate expiration
        # TikTok usually gives expires_in (often 24 hours)
        expires_in = token_data.get("expires_in", 86400)
        expires_at = (datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)).isoformat()

        # 4. Save to Database
        # Matches: (user_id, platform, access_token, refresh_token, expires_at, platform_user_id)
        UserManager.save_social_account(
            user_id,
            "tiktok",
            token_data["access_token"],
            token_data.get("refresh_token"),
            expires_at,
            token_data.get("open_id") # This is the TikTok unique User ID
        )

        # return {
        #     "status": "success", 
        #     "message": "TikTok account connected successfully",
        #     "tiktok_user_id": token_data.get("open_id")
        # }
        return RedirectResponse(f"{APP_REDIRECT_URI}?platform=tiktok")

    except Exception as e:
        print(f"ERROR in TikTok Callback: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
# @router.post("/upload-tiktok")
# async def upload_tiktok(
#     video_file: UploadFile = File(...),
#     access_token: str = Form(...),
#     caption: str = Form(...)
# ):
#     # 1. Prepare file info
#     # We need the exact byte size for TikTok's initialization
#     content = await video_file.read()
#     video_size = len(content)
    
#     # 2. STEP 1: Initialize the Upload
#     # Endpoint for Direct Post (ensure your app has 'video.publish' scope)
#     init_url = "https://open.tiktokapis.com/v2/post/publish/video/init/"
    
#     headers = {
#         "Authorization": f"Bearer {access_token}",
#         "Content-Type": "application/json; charset=UTF-8"
#     }
    
#     init_data = {
#         "post_info": {
#             "title": caption,
#             "privacy_level": "SELF_ONLY", # Change to "SELF_ONLY" for sandbox testing, change to "PUBLIC_TO_ANYONE" for production
#             "disable_comment": False,
#             "video_cover_timestamp_ms": 1000
#         },
#         "source_info": {
#             "source": "FILE_UPLOAD",
#             "video_size": video_size,
#             "chunk_size": video_size, # For videos < 64MB, we can use 1 chunk
#             "total_chunk_count": 1
#         }
#     }
    
#     init_response = requests.post(init_url, json=init_data, headers=headers)
#     init_res_json = init_response.json()
    
#     if init_response.status_code != 200 or "data" not in init_res_json:
#         raise HTTPException(status_code=400, detail=f"TikTok Init Failed: {init_res_json}")

#     upload_url = init_res_json["data"]["upload_url"]
#     publish_id = init_res_json["data"]["publish_id"]

#     # 3. STEP 2: Upload the Binary File
#     # TikTok requires a PUT request with specific headers for the file data
#     put_headers = {
#         "Content-Type": "video/mp4",
#         "Content-Length": str(video_size),
#         "Content-Range": f"bytes 0-{video_size - 1}/{video_size}"
#     }
    
#     upload_response = requests.put(upload_url, data=content, headers=put_headers)
    
#     if upload_response.status_code in [200, 201]:
#         return {
#             "status": "success",
#             "publish_id": publish_id,
#             "message": "Video is now being processed by TikTok!"
#         }
#     else:
#         return {
#             "status": "error",
#             "details": upload_response.text
#         }