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

router = APIRouter()
# BASE_URL = "http://localhost:8000"
BASE_URL = "https://youlanda-migratory-trevor.ngrok-free.dev"



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
        "access_token": access_token,
        "available_accounts": ig_accounts
    }


async def process_and_publish_reel(creation_id, instagram_id, access_token, paths):
    print(f"DEBUG: Background task started for container: {creation_id}")
    time.sleep(40)

    for i in range(20):
        status_url = f"https://graph.facebook.com/v18.0/{creation_id}"
        status_data = requests.get(status_url, params={
            "fields": "status_code,status",
            "access_token": access_token
        }).json()

        print(f"DEBUG Background status (Attempt {i+1}): {status_data}")

        if status_data.get("status_code") == "FINISHED":
            publish_res = requests.post(f"https://graph.facebook.com/v18.0/{instagram_id}/media_publish", data={
                "creation_id": creation_id,
                "access_token": access_token    
            }).json()
            print(f"DEBUG: PUBLISH SUCCESS: {publish_res.get('id')}")
            break
        
        time.sleep(15)

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

        final_clip.write_videofile(processed_path, codec="libx264", audio_codec="aac")
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
    

# @router.post("/upload-reel")
# async def upload_reel(
#     access_token: str = Form(...),
#     instagram_id: str = Form(...),
#     caption: str = Form(...),
#     file: UploadFile = File(...),
# ):
#     clear_static_folder("static")
#     original_path = None
#     processed_path = None
    
#     try:
#         # 1. Save original
#         file_extension = file.filename.split(".")[-1]
#         unique_id = str(uuid.uuid4())
#         original_path = os.path.join("static", f"{unique_id}_orig.{file_extension}")

#         with open(original_path, "wb") as buffer:
#             shutil.copyfileobj(file.file, buffer)

#         # 2. Force MoviePy to process it
#         clip = VideoFileClip(original_path)
#         w, h = clip.size
#         print(f"DEBUG: MoviePy sees dimensions: {w}x{h}")
        
#         target_ratio = 9/16
#         current_ratio = w/h

#         # We will create a NEW file for Instagram no matter what
#         processed_path = os.path.join("static", f"{unique_id}_final.mp4")

#         if abs(current_ratio - target_ratio) > 0.01:
#             print(f"DEBUG: Aspect ratio {current_ratio:.2f} is not 0.56. CROPPING...")
#             new_w = h * target_ratio
#             x1 = (w - new_w) / 2
#             x2 = x1 + new_w
#             # Center crop
#             final_clip = clip.cropped(x1=x1, x2=x2, y1=0, y2=h)
#         else:
#             print("DEBUG: Aspect ratio is already correct. Just re-encoding...")
#             final_clip = clip

#         # Write the file (This is the most important step)
#         final_clip.write_videofile(processed_path, codec="libx264", audio_codec="aac")
#         final_clip.close()
#         clip.close()

#         # 3. Use the PROCESSED path for the URL
#         final_filename = os.path.basename(processed_path)
#         public_video_url = f"{BASE_URL}/static/{final_filename}"
#         print(f"DEBUG: Instagram will download from: {public_video_url}")

#         # 4. Container Creation
#         payload = {
#             "media_type": "REELS",
#             "video_url": public_video_url,
#             "caption": caption,
#             "share_to_feed": "true",
#             "access_token": access_token
#         }

#         container_res = requests.post(f"https://graph.facebook.com/v18.0/{instagram_id}/media", data=payload).json()
#         if "id" not in container_res:
#             return JSONResponse(status_code=400, content={"detail": f"Container failed: {container_res}"})
        
#         creation_id = container_res["id"]

#         print("DEBUG: Container created. Waiting 30 seconds for IG to download...")
#         time.sleep(30)
        
#         # 5. Polling (Waiting for IG to download and process)
#         # 5. Polling
#         for i in range(30):
#             status_data = requests.get(f"https://graph.facebook.com/v18.0/{creation_id}", params={
#                 "fields": "status_code,status",
#                 "access_token": access_token
#             }).json()

#             print(f"DEBUG Status (Attempt {i+1}): {status_data}")

#             if status_data.get("status_code") == "FINISHED":
#                 break
            
#             # If we see 'IN_PROGRESS', just keep waiting
#             if status_data.get("status_code") == "IN_PROGRESS":
#                 time.sleep(10)
#                 continue

#             if status_data.get("status_code") == "ERROR":
#                 # Check if it's actually an error or just needs more time
#                 # We'll give it 3 retries even on 'ERROR' to be safe
#                 if i < 3:
#                     print("DEBUG: Caught a false-start error, retrying...")
#                     time.sleep(15)
#                     continue
#                 return JSONResponse(status_code=400, content={"detail": f"IG rejected video: {status_data.get('status')}"})
            
#         # 6. Final Publish
#         publish_res = requests.post(f"https://graph.facebook.com/v18.0/{instagram_id}/media_publish", data={
#             "creation_id": creation_id,
#             "access_token": access_token    
#         }).json()

#         return {"status": "success", "ig_post_id": publish_res.get("id")}
    
#     except Exception as e:
#         print(f"ERROR: {str(e)}")
#         raise HTTPException(status_code=500, detail=str(e))
    
#     finally:
#         # 7. Wait for Instagram to finish downloading before deleting!
#         # This is likely why you were getting 404s
#         print("DEBUG: Waiting 15 seconds before deleting files...")
        
