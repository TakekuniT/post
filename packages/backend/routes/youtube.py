import shutil
from fastapi import APIRouter, UploadFile, Form, File, HTTPException, Request
from fastapi.responses import RedirectResponse, JSONResponse
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from googleapiclient.http import MediaFileUpload
import os
import urllib.parse
import requests
import subprocess
from utils.db_client import UserManager
from datetime import datetime, timedelta
from jose import jwt, jwk # from python-jose
from dotenv import load_dotenv
import json 
from utils.limiter import limiter
load_dotenv()

router = APIRouter()

CLIENT_ID = os.environ.get("YOUTUBE_CLIENT_ID")
CLIENT_SECRET = os.environ.get("YOUTUBE_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("YOUTUBE_REDIRECT_URI")
APP_REDIRECT_URI = os.getenv("APP_REDIRECT_URI")


jwk_dict = json.loads(os.getenv("SUPABASE_JWK_SECRET"))
actual_key = jwk_dict["keys"][0]
public_key = jwk.construct(actual_key, algorithm="ES256")

# In your YouTube login route file
SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.readonly",
    "openid",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/userinfo.email"
]

@router.get("/")
def test_youtube():
    return {"message": "Youtube route is working"}

@router.get("/login")
@limiter.limit("10/minute")
def youtube_login(request: Request, token: str):
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
    

    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": " ".join(SCOPES),
        "response_type": "code",
        "access_type": "offline", # Crucial for refresh_token
        "prompt": "consent",      # Ensures refresh_token is sent every time
        "state": verified_user_id          # Pass user_id to callback
    }
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(auth_params)
    return RedirectResponse(auth_url)

@router.get("/callback")
@limiter.limit("10/minute")
async def youtube_callback(request: Request, code: str, state: str):
    user_id = state
    token_url = "https://oauth2.googleapis.com/token"
    data = {
        "code": code,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code"
    }

    response = requests.post(token_url, data=data)
    if response.status_code != 200:
        raise HTTPException(status_code=400, detail=response.json())
    
    tokens = response.json()
    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token") # Will be present due to 'offline' access
    expires_in = tokens.get("expires_in", 3600)

    try:
        # 1. Use the access_token to get the YouTube Channel ID
        creds = Credentials(token=access_token)
        youtube = build("youtube", "v3", credentials=creds)
        
        # Request the 'mine' channel
        channels_res = youtube.channels().list(
            part="id,snippet",
            mine=True
        ).execute()

        if not channels_res.get("items"):
            raise HTTPException(status_code=404, detail="No YouTube channel found for this account.")

        channel = channels_res["items"][0]
        channel_id = channel["id"]
        channel_name = channel["snippet"]["title"]

        # 2. Calculate expiration timestamp
        #expires_at = (datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)).isoformat()
        expires_at = (datetime.utcnow() + timedelta(seconds=expires_in)).isoformat()
        # 3. Save to Database
        # Signature: (user_id, platform, access_token, refresh_token, expires_at, platform_user_id)
        UserManager.save_social_account(
            user_id,
            "youtube",
            access_token,
            refresh_token,
            expires_at,
            channel_id
        )

        # return {
        #     "status": "success", 
        #     "message": f"Connected YouTube channel: {channel_name}",
        #     "channel_id": channel_id
        # }
        return RedirectResponse(f"{APP_REDIRECT_URI}?platform=youtube")

    except Exception as e:
        print(f"ERROR in YouTube Callback: {e}")
        raise HTTPException(status_code=500, detail=str(e))




# in memory token for MVP, replace with DB later
TOKENS = {}

@router.post("/upload-short")
async def upload_short(
    access_token: str = Form(...),
    title: str = Form(...),
    description: str = Form(...),
    file: UploadFile = File(...),
):
    if file is None:
        return JSONResponse({"error": "No file provided"}, status_code=400)
    
    # save file temp
    temp_path = f"/tmp/{file.filename}"
    try:
        with open(temp_path, "wb") as f:
            #f.write(file.file.read())
            shutil.copyfileobj(file.file, f)
    except Exception as e:
        return {"error": f"Failed to save temp file: {str(e)}"}
    
    # check if video is short
    # try:
    #     result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", temp_path], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    #     duration = float(result.stdout)
    #     if duration > 60:
    #         os.remove(temp_path)
    #         return JSONResponse({"error": "Video is too long"}, status_code=400)
    # except Exception:
    #     pass

    try:
        # create youtube client
        #youtube = build("youtube", "v3", developerKey=None, credentials=None)
        creds = Credentials(token=access_token)
        youtube = build("youtube", "v3", credentials=creds)

        # set access token
        #youtube._http.headers.update({"Authorization": f"Bearer {access_token}"})

        #media = MediaFileUpload(temp_path, chunksize=-1, resumable=True)
        media = MediaFileUpload(
            temp_path, 
            mimetype='video/mp4', # Be explicit about type
            chunksize=1024*1024,  # 1MB chunks
            resumable=True
        )
        request = youtube.videos().insert(
            part="snippet,status",
            body={
                "snippet": {
                    "title": f"{title}",
                    "description": f"{description}",
                    "categoryId": "22"
                },
                "status": {
                    "privacyStatus": "public",
                    "selfDeclaredMadeForKids": False
                }
            },
            media_body=media
        )
        response = None
        while response is None:
            status, response = request.next_chunk()
            if status:
                print(f"Uploaded {int(status.progress() * 100)}%")
        return {"message": "Video uploaded successfully", "video_id": response["id"]}
    except Exception as e:
        return {"error": str(e)}
    finally:
        if os.remove(temp_path):
            os.remove(temp_path)
