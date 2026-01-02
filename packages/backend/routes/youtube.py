from fastapi import APIRouter, UploadFile, Form, File
from fastapi.responses import RedirectResponse, JSONResponse
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from googleapiclient.http import MediaFileUpload
import os
import urllib.parse
import requests
import subprocess


router = APIRouter()

CLIENT_ID = os.environ.get("YOUTUBE_CLIENT_ID")
CLIENT_SECRET = os.environ.get("YOUTUBE_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("YOUTUBE_REDIRECT_URI")
SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]

@router.get("/")
def test_youtube():
    return {"message": "Youtube route is working"}

@router.get("/login")
def youtube_login():
    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": " ".join(SCOPES),
        "response_type": "code",
        "access_type": "offline",
        "prompt": "consent"
    }
    print(auth_params)
    auth_params["scope"] = "%20".join(SCOPES)
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(auth_params)
    return RedirectResponse(auth_url)

@router.get("/callback")
def youtube_callback(code: str):
    # Exchanges authorization code for access token
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
        return {"error": response.json()}
    
    tokens = response.json()
    return tokens





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
    with open(temp_path, "wb") as f:
        f.write(file.file.read())
    
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

        media = MediaFileUpload(temp_path, chunksize=-1, resumable=True)
        request = youtube.videos().insert(
            part="snippet,status",
            body={
                "snippet": {
                    "title": f"{title}",
                    "description": f"{description}",
                },
                "status": {
                    "privacyStatus": "public",
                }
            },
            media_body=media
        )
        response = request.execute()
        return {"message": "Video uploaded successfully", "video_id": response["id"]}
    except Exception as e:
        return {"error": str(e)}
    finally:
        if os.remove(temp_path):
            os.remove(temp_path)
