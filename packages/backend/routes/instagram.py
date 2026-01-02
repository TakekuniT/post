from fastapi import APIRouter, Query, HTTPException, File, UploadFile, Form
from fastapi.responses import RedirectResponse, JSONResponse
import requests
import os
import urllib.parse
import uuid 
import time
from fastapi.staticfiles import StaticFiles

router = APIRouter()
BASE_URL = "http://localhost:8000"

# Set up static files
if not os.path.exists("static"):
    os.mkdir("static")
router.mount("/static", StaticFiles(directory="static"), name="static")

CLIENT_ID = os.environ.get("INSTAGRAM_CLIENT_ID")
CLIENT_SECRET = os.environ.get("INSTAGRAM_CLIENT_SECRET")
REDIRECT_URI = os.environ.get("INSTAGRAM_REDIRECT_URI")

SCOPES = [
    "instagram_basic",
    "instagram_content_publish",
    "pages_read_engagement",
    "pages_show_list",
    "business_management", 
    "public_profile"
]

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


@router.post("/upload-reel")
async def upload_reel(
    access_token: str = Form(...),
    instagram_id: str = Form(...),
    caption: str = Form(...),
    file: UploadFile = File(...),
):
    try:
        # save mobile file to server
        file_extension = file.filename.split(".")[-1]
        unique_filename = f"{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join("static", unique_filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # create the public URL instagram will use
        public_video_url = f"{BASE_URL}/static/{unique_filename}"

        # create instagram media container
        container_url = f"https://graph.facebook.com/v18.0/{instagram_id}/media"
        payload = {
            "media_type": "REELS",
            "video_url": public_video_url,
            "caption": caption,
            "shared_to_feed": "true",
            "access_token": access_token
        }

        container_res = requests.post(container_url, data=payload).json()
        if "id" not in container_res:
            return HTTPException(status_code=400, detail=f"Container failed: {container_res}")
        
        creation_id = container_res["id"]

        # wait for processing
        status_url = f"https://graph.facebook.com/v18.0/{creation_id}"
        for _ in range(20):
            time.sleep(10)
            status_data = requests.get(status_url, params={
                "fields": "status_code",
                "access_token": access_token
            }).json()

            if status_data.get("status_code") == "FINISHED":
                break
            if status_data.get("status_code") == "ERROR":
                return HTTPException(status_code=400, detail=f"Upload failed: {status_data}")
        else:
            return {"error": "Processing timed out, the Reel might still be posted later"}
        
        # publish the reel
        publish_url = f"https://graph.facebook.com/v18.0/{instagram_id}/media_publish"
        final_res = requests.post(publish_url, data={
            "creation_id": creation_id,
            "access_token": access_token    
        }).json()

        return {"status": "success", "ig_post_id": final_res.get("id")}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))