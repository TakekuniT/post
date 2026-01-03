from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel
from services.post_manager import PostManager
import os

router = APIRouter()

class PublishRequest(BaseModel):
    user_id: str
    video_path: str # In production, this might be a Supabase Storage URL
    caption: str
    title: str
    platforms: list[str]

@router.post("/publish")
async def publish_video(request: PublishRequest, background_tasks: BackgroundTasks):
    # 1. Quick Validation
    if not os.path.exists(request.video_path):
        raise HTTPException(status_code=400, detail="Video file not found")

    # 2. Hand off to background tasks (The user doesn't have to wait!)
    background_tasks.add_task(
        PostManager.distribute_video,
        request.user_id,
        request.video_path,
        request.caption,
        request.title,
        request.platforms
    )

    return {"status": "Processing", "message": f"Upload started for {request.platforms}"}