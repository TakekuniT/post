from fastapi import APIRouter, BackgroundTasks, HTTPException, Depends
from pydantic import BaseModel
from services.post_manager import PostManager
import os
from utils.db_client import supabase
import shutil
from pathlib import Path
from typing import Optional, List
from datetime import datetime
from services.subscription_service import SubscriptionService
from utils.db_client import supabase
from utils.oauth import get_current_user
from utils.limiter import limiter
from fastapi import Request
router = APIRouter()


class PublishRequestPhotos(BaseModel):
    user_id: str
    photo_paths: list[str]
    caption: str
    platforms: list[str]
    scheduled_at: Optional[datetime] = None

class PublishRequest(BaseModel):
    user_id: str
    video_path: str 
    caption: str
    description: str
    platforms: list[str]
    scheduled_at: Optional[datetime] = None

async def get_local_photo(file_name: str) -> str:
    """Download photo from Supabase and return a local path"""
    base_dir = Path(__file__).resolve().parents[1]
    static_dir = base_dir / "static"
    static_dir.mkdir(exist_ok=True)

    local_path = str(static_dir / file_name)
    if not os.path.exists(local_path):
        print(f"DEBUG: File not found locally. Downloading to: {local_path}")
        data = supabase.storage.from_("photos").download(file_name)
        with open(local_path, "wb") as f:
            f.write(data)
            
    return local_path

async def get_local_video(file_name: str) -> str:
    """Download video from Supabase and return a local path"""
    # local_path = os.path.join("static", file_name)  # or /tmp
    # if not os.path.exists(local_path):
    #     data = supabase.storage.from_("videos").download(file_name)
    #     with open(local_path, "wb") as f:
    #         f.write(data)
    # return local_path

    # Get the absolute path to your 'backend' directory
    base_dir = Path(__file__).resolve().parents[1] 
    static_dir = base_dir / "static"
    static_dir.mkdir(exist_ok=True)
    
    local_path = str(static_dir / file_name)
    
    if not os.path.exists(local_path):
        print(f"DEBUG: File not found locally. Downloading to: {local_path}")
        data = supabase.storage.from_("videos").download(file_name)
        with open(local_path, "wb") as f:
            f.write(data)
            
    return local_path


@router.post("/photos")
@limiter.limit("5/minute")
async def publish_photos(
    request: Request,
    publish_request: PublishRequestPhotos,
    background_tasks: BackgroundTasks,
    authenticated_user_id: str = Depends(get_current_user)
):
    safe_user_id = authenticated_user_id
    user_perms = await SubscriptionService.get_user_permissions(safe_user_id, supabase)
    if not user_perms:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    if len(publish_request.platforms) > user_perms["max_platforms"]:
        raise HTTPException(
            status_code=403, 
            detail=f"Your tier allows max {user_perms['max_platforms']} platforms."
        )

    if publish_request.scheduled_at and not user_perms.get("can_schedule", True): # Add this to your TIER_CONFIG
         raise HTTPException(
            status_code=403, 
            detail="Scheduling is only available for Pro and Elite tiers."
        )
    db_entry = {
        "user_id": safe_user_id, #request.user_id,
        "caption": publish_request.caption,
        "photo_paths": publish_request.photo_paths, 
        "platforms": publish_request.platforms,
        "scheduled_at": publish_request.scheduled_at.isoformat() if publish_request.scheduled_at else None,
        "status": "pending" if publish_request.scheduled_at else "published",
        "platform_links": {}
    }

    response = supabase.table("posts").insert(db_entry).execute()
    post_id = response.data[0]["id"]

    local_paths = []
    for photo_path in publish_request.photo_paths:
        local_path = await get_local_photo(photo_path)
        local_paths.append(local_path)
    
    if not publish_request.scheduled_at:
        try:
            print(f"DEBUG: Uploading {len(local_paths)} photos...")
            background_tasks.add_task(
                PostManager.distribute_photos,
                post_id, # pass post id to background
                safe_user_id,
                local_paths,
                publish_request.caption,
                publish_request.platforms
            )
            print(f"DEBUG: Photo upload complete.")
            return {"status": "Processing", "message": f"Immediate upload started for {publish_request.platforms}"}
        except Exception as e:
            print(f"Error: {str(e)}")
            return {"status": "Error", "message": f"Failed to distribute photos: {str(e)}"}
    else:
        return {"status": "Scheduled", "message": f"Post queued for {publish_request.platforms}"}


@router.post("")
@limiter.limit("5/minute")
async def publish_video(
    request: Request,
    publish_request: PublishRequest,
    background_tasks: BackgroundTasks,
    authenticated_user_id: str = Depends(get_current_user)
):
    safe_user_id = authenticated_user_id

    # static_folder = Path(__file__).resolve().parents[1] / "static"
    # if static_folder.exists() and static_folder.is_dir():
    #     # Remove all files and folders inside static
    #     for item in static_folder.iterdir():
    #         if item.is_file():
    #             item.unlink()
    #         elif item.is_dir():
    #             shutil.rmtree(item)



    # 1. Quick Validation
    # if not os.path.exists(request.video_path):
    #     raise HTTPException(status_code=400, detail="Video file not found")

    # user_perms = await SubscriptionService.get_user_permissions(request.user_id, supabase)
    # for extra security, we'll check the user_id in the JWT token
    user_perms = await SubscriptionService.get_user_permissions(safe_user_id, supabase)
    if not user_perms:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    if len(publish_request.platforms) > user_perms["max_platforms"]:
        raise HTTPException(
            status_code=403, 
            detail=f"Your tier allows max {user_perms['max_platforms']} platforms."
        )

    if publish_request.scheduled_at and not user_perms.get("can_schedule", True): # Add this to your TIER_CONFIG
         raise HTTPException(
            status_code=403, 
            detail="Scheduling is only available for Pro and Elite tiers."
        )
    
    
    
    # 2. Prepare DB entry for Supabase
    db_entry = {
        "user_id": safe_user_id, #request.user_id,
        "caption": publish_request.caption,
        "description": publish_request.description,
        "video_path": publish_request.video_path,
        "platforms": publish_request.platforms,
        "scheduled_at": publish_request.scheduled_at.isoformat() if publish_request.scheduled_at else None,
        # "status": "pending" if publish_request.scheduled_at else "published",
        "status": "pending" if publish_request.scheduled_at else "uploading",
        "platform_links": {}
    }

    # 3. Save to Supabase
    # supabase.table("posts").upsert(db_entry).execute()
    response = supabase.table("posts").insert(db_entry).execute()
    post_id = response.data[0]["id"]



    # 4. Publish now or wait for scheduler

    if not publish_request.scheduled_at:
        local_path = await get_local_video(publish_request.video_path)

        background_tasks.add_task(
            PostManager.distribute_video,
            post_id, # pass post id to background
            safe_user_id,
            local_path,
            publish_request.caption,
            publish_request.description,
            publish_request.platforms
        )
        return {"status": "Processing", "message": f"Immediate upload started for {publish_request.platforms}"}
    else:
        return {"status": "Scheduled", "message": f"Post queuedfor {publish_request.platforms}"}
    


PublishRequest.model_rebuild()
PublishRequestPhotos.model_rebuild()