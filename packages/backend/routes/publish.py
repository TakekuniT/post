from fastapi import APIRouter, UploadFile, File, Form, BackgroundTasks
from models.user import UserManager
from utils.oauth import OAuthManager
from routes.instagram import publish_to_instagram # Import your existing logic
from routes.youtube import upload_to_youtube     # Import your existing logic
import asyncio

router = APIRouter()
oauth = OAuthManager()

@router.post("/publish-all")
async def publish_all(
    background_tasks: BackgroundTasks,
    user_id: str = Form(...),
    caption: str = Form(...),
    title: str = Form(""), # YouTube specific
    platforms: str = Form(...), # Pass as a comma-separated string like "instagram,youtube"
    file: UploadFile = File(...)
):
    # 1. Process platforms list
    platform_list = [p.strip() for p in platforms.split(",")]
    
    # 2. Save the file locally first so all platforms can access the same path
    file_path = f"static/{user_id}_{file.filename}"
    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())

    results = {}

    for platform in platform_list:
        # 3. Fetch tokens from Supabase
        account = UserManager.get_social_tokens(user_id, platform)
        if not account:
            results[platform] = "Account not linked"
            continue

        # 4. Global Token Refresh Check
        current_token = account['access_token']
        if platform == 'youtube':
            # YouTube check: if close to expiry, refresh it
            # (You'd check account['expires_at'] here)
            new_tokens = oauth.refresh_youtube_token(account['refresh_token'])
            current_token = new_tokens['access_token']
            # Update Supabase with the fresh token
            UserManager.save_social_account(user_id, 'youtube', new_tokens)

        # 5. Trigger platform-specific uploads
        if platform == "instagram":
            # Start the IG polling process in the background
            background_tasks.add_task(
                publish_to_instagram, 
                video_url=f"https://your-ngrok.dev/{file_path}", 
                instagram_id=account['platform_user_id'],
                access_token=current_token,
                caption=caption
            )
        
        if platform == "youtube":
            background_tasks.add_task(
                upload_to_youtube,
                file_path=file_path,
                access_token=current_token,
                title=title or caption[:100],
                description=caption
            )

    return {"status": "Processing", "platforms": platform_list}