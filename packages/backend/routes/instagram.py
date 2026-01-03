from fastapi import APIRouter, Query, HTTPException, File, UploadFile, Form, BackgroundTasks
from fastapi.responses import RedirectResponse, JSONResponse
import requests
import os
import urllib.parse
import uuid 
import time
from fastapi.staticfiles import StaticFiles
import shutil
from moviepy import VideoFileClip
import moviepy.video.fx as fix
import asyncio  


router = APIRouter()
# BASE_URL = "http://localhost:8000"
BASE_URL = "https://youlanda-migratory-trevor.ngrok-free.dev"
# BASE_URL = "https://xpost-dev-taki.loca.lt"


CLIENT_ID = os.environ.get("INSTAGRAM_CLIENT_ID")
CLIENT_SECRET = os.environ.get("INSTAGRAM_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("INSTAGRAM_REDIRECT_URI")

SCOPES = [
    "instagram_basic",             # This is still the standard for FB-connected accounts
    "instagram_content_publish",   # This is the standard for Reels
    "pages_read_engagement",
    "pages_show_list",
    "public_profile"
]

def clear_static_folder(static_dir):
    if not os.path.exists(static_dir):
        print("DEBUG: static folder does not exist")
        return

    for filename in os.listdir(static_dir):
        file_path = os.path.join(static_dir, filename)

        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)  # delete file or symlink
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)  # delete subdirectory
        except Exception as e:
            print(f"ERROR deleting {file_path}: {e}")

    print("DEBUG: static folder cleared")

@router.get("/")
def test_instagram():
    return {"message": "Instagram route is working"}

@router.get("/login")
def instagram_login():
    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": ",".join(SCOPES),
        "response_type": "code",
    }
    #auth_url = "https://api.instagram.com/oauth/authorize?" + urllib.parse.urlencode(auth_params)
    auth_url = "https://www.facebook.com/v18.0/dialog/oauth?" + urllib.parse.urlencode(auth_params)
    return RedirectResponse(auth_url)

@router.get("/callback")
def instagram_callback(code: str = None):
    if not code:
        return JSONResponse({"error": "No code provided"}, status_code=400)
    
    # exchange code for user access token
    
    # token_url = "https://api.instagram.com/oauth/access_token"
    token_url = "https://graph.facebook.com/v18.0/oauth/access_token"
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
        "code": code
    }
    # response = requests.post(token_url, data=data)
    # if response.status_code != 200:
    #     return {"error": response.json()}
    # tokens = response.json()
    # return tokens
    token_res = requests.get(token_url, params=data).json()
    access_token = token_res.get("access_token")
    print(f"DEBUG: Success! Access Token received (starts with: {access_token[:10]}...)")
    

    # find instagram business account
    accounts_url = f"https://graph.facebook.com/v18.0/me/accounts?fields=name,instagram_business_account&access_token={access_token}"
    accounts_res = requests.get(accounts_url).json()
    print(f"RAW DATA FROM FACEBOOK: {accounts_res}")

    # extract id (let users choose from the list)
    pages = accounts_res.get("data", [])
    ig_accounts = []
    for page in pages:
        if "instagram_business_account" in page:
            ig_accounts.append({
                "page_name": page["name"],
                "instagram_id": page["instagram_business_account"]["id"]
            })
    if not ig_accounts:
        return {"error": "No IG business account found. Ensure your IG is Business/Creator and linked to a FB page."}
    
    return {
        "status": "success", 
        "token_data": token_res, 
        "instagram_accounts": ig_accounts
    }


async def process_and_publish_reel(creation_id, instagram_id, access_token, paths_to_delete):
    print(f"DEBUG: Background task started for container {creation_id}")
    
    # 1. INCREASE INITIAL WAIT
    # Instagram often takes 45-60 seconds to fully "digest" a video from a tunnel
    time.sleep(60) 

    for i in range(30):
        status_url = f"https://graph.facebook.com/v18.0/{creation_id}"
        status_data = requests.get(status_url, params={
            "fields": "status_code,status",
            "access_token": access_token
        }).json()

        print(f"DEBUG Background Status (Attempt {i+1}): {status_data}")

        if status_data.get("status_code") == "FINISHED":
            # ... publish logic ...
            break
            
        # 2. BE PATIENT WITH ERRORS
        # If it's the 2207077 error, DON'T STOP. 
        # Sometimes IG reports this while it's still retrying the download.
        if status_data.get("status_code") == "ERROR":
            print("DEBUG: IG reported error. Retrying anyway for 2 more minutes...")
            if i > 10: # Only truly give up after 10 attempts (approx 3 mins)
                 print("DEBUG: Final failure.")
                 break
        
        time.sleep(20) # Longer sleep between polls

@router.post("/upload-reel")
async def upload_reel(
    background_tasks: BackgroundTasks,
    access_token: str = Form(...),
    instagram_id: str = Form(...),
    caption: str = Form(...),
    file: UploadFile = File(...),
):
    try:
        # 1. Clear old files to keep Mac clean
        clear_static_folder("static")
        
        # 2. Save original
        file_extension = file.filename.split(".")[-1]
        unique_id = str(uuid.uuid4())
        original_path = os.path.join("static", f"{unique_id}_orig.{file_extension}")

        with open(original_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 3. MoviePy Processing
        clip = VideoFileClip(original_path)
        w, h = clip.size
        target_ratio = 9/16
        processed_path = os.path.join("static", f"{unique_id}_final.mp4")

        if abs((w/h) - target_ratio) > 0.01:
            print(f"DEBUG: Cropping {w}x{h} to 9:16")
            new_w = h * target_ratio
            x1 = (w - new_w) / 2
            x2 = x1 + new_w
            final_clip = clip.cropped(x1=x1, x2=x2, y1=0, y2=h)
        else:
            final_clip = clip

        final_clip.write_videofile(processed_path, codec="libx264", audio_codec="aac", ffmpeg_params=["-movflags", "faststart"])
        final_clip.close()
        clip.close()

        # 4. URL for Instagram (Ensure BASE_URL is your HTTPS ngrok link)
        final_filename = os.path.basename(processed_path)
        public_video_url = f"{BASE_URL}/static/{final_filename}"
        print(f"DEBUG: Sending URL to IG: {public_video_url}")
        
        # 5. Container Creation
        container_url = f"https://graph.facebook.com/v18.0/{instagram_id}/media"
        payload = {
            "media_type": "REELS",
            "video_url": public_video_url,
            "caption": caption,
            "share_to_feed": "true",
            "access_token": access_token
        }

        container_res = requests.post(container_url, data=payload).json()
        creation_id = container_res.get("id")

        if not creation_id:
            print(f"DEBUG: Container failed. Full response: {container_res}")
            return JSONResponse(status_code=400, content={"error": "Container creation failed", "details": container_res})

        # 6. Launch background task
        background_tasks.add_task(
            process_and_publish_reel,
            creation_id,
            instagram_id,
            access_token,
            [original_path, processed_path]
        )

        return {
            "status": "processing_started",
            "creation_id": creation_id,
            "video_url": public_video_url,
            "message": "Upload started. Check server logs for background progress."
        }

    except Exception as e:
        print(f"CRASH: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
    



@router.post("/prepare-reel")
async def prepare_reel(file: UploadFile = File(...)):
    try:
        # Clear static folder to avoid confusion
        if os.path.exists("static"):
            shutil.rmtree("static")
        os.mkdir("static")

        file_extension = file.filename.split(".")[-1]
        unique_id = str(uuid.uuid4())
        original_path = os.path.join("static", f"{unique_id}_orig.{file_extension}")
        processed_path = os.path.join("static", f"{unique_id}_final.mp4")

        with open(original_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # MoviePy Processing
        clip = VideoFileClip(original_path)
        w, h = clip.size
        target_ratio = 9/16
        
        if abs((w/h) - target_ratio) > 0.01:
            new_w = h * target_ratio
            x1 = (w - new_w) / 2
            x2 = x1 + new_w
            final_clip = clip.cropped(x1=x1, x2=x2, y1=0, y2=h)
        else:
            final_clip = clip

        # FastStart is KEY for Instagram to read the file over ngrok
        final_clip.write_videofile(
            processed_path, 
            codec="libx264", 
            audio_codec="aac",
            ffmpeg_params=["-movflags", "faststart"]
        )
        final_clip.close()
        clip.close()

        public_video_url = f"{BASE_URL}/static/{os.path.basename(processed_path)}"
        print(f"DEBUG: Sending URL to IG: {public_video_url}")
        return {
            "status": "ready",
            "video_url": public_video_url,
            "instruction": "Verify this URL plays in an Incognito window, then call /publish-reel"
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    


@router.post("/publish-reel")
async def publish_reel(
    video_url: str = Form(...),
    access_token: str = Form(...),
    instagram_id: str = Form(...),
    caption: str = Form(...)
):
    # 1. Create Container (Keep using requests for the initial call is fine)
    container_url = f"https://graph.facebook.com/v18.0/{instagram_id}/media"
    payload = {
        "media_type": "REELS",
        "video_url": video_url,
        "caption": caption,
        "share_to_feed": "true",
        "access_token": access_token
    }

    res = requests.post(container_url, data=payload).json()
    creation_id = res.get("id")
    if not creation_id:
        return JSONResponse(status_code=400, content={"error": "Container failed", "details": res})

    print(f"DEBUG: Container {creation_id} created. Polling starts...")

    # 2. ASYNCHRONOUS Polling
    for i in range(30): 
        await asyncio.sleep(20) 
        
        status_res = requests.get(f"https://graph.facebook.com/v18.0/{creation_id}", params={
            "fields": "status_code,status",
            "access_token": access_token
        }).json()

        status_code = status_res.get("status_code")
        print(f"DEBUG: Attempt {i+1} - {status_code}")

        if status_code == "FINISHED":
            # 3. Final Publish
            publish_url = f"https://graph.facebook.com/v18.0/{instagram_id}/media_publish"
            final_res = requests.post(publish_url, data={
                "creation_id": creation_id,
                "access_token": access_token
            }).json()
            return {"status": "success", "post_id": final_res.get("id")}
        
        if status_code == "ERROR":
            error_msg = status_res.get("status", "")
            if "2207077" in error_msg or "2207076" in error_msg:
                continue 
            return JSONResponse(status_code=400, content={"error": "IG Error", "details": status_res})

    return JSONResponse(status_code=408, content={"error": "Timeout or persistent IG error"})