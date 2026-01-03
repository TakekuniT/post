from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel
from services.post_manager import PostManager
import os
from utils.db_client import supabase
import shutil
from pathlib import Path

router = APIRouter()

class PublishRequest(BaseModel):
    user_id: str
    video_path: str # In production, this might be a Supabase Storage URL
    caption: str
    title: str
    platforms: list[str]

async def get_local_video(file_name: str) -> str:
    """Download video from Supabase and return a local path"""
    local_path = os.path.join("static", file_name)  # or /tmp
    if not os.path.exists(local_path):
        data = supabase.storage.from_("videos").download(file_name)
        with open(local_path, "wb") as f:
            f.write(data)
    return local_path


@router.post("")
async def publish_video(request: PublishRequest, background_tasks: BackgroundTasks):
    static_folder = Path(__file__).resolve().parents[1] / "static"
    if static_folder.exists() and static_folder.is_dir():
        # Remove all files and folders inside static
        for item in static_folder.iterdir():
            if item.is_file():
                item.unlink()
            elif item.is_dir():
                shutil.rmtree(item)
    # 1. Quick Validation
    # if not os.path.exists(request.video_path):
    #     raise HTTPException(status_code=400, detail="Video file not found")
    local_path = await get_local_video(request.video_path)
    # 2. Hand off to background tasks (The user doesn't have to wait!)
    background_tasks.add_task(
        PostManager.distribute_video,
        request.user_id,
        local_path,
        request.caption,
        request.title,
        request.platforms
    )

    return {"status": "Processing", "message": f"Upload started for {request.platforms}"}