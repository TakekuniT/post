from fastapi import APIRouter, UploadFile, Form
from fastapi.responses import JSONResponse
import os
import subprocess

router = APIRouter()

# in memory token for MVP, replace with DB later
TOKENS = {}

@router.post("/upload-short")
async def upload_short(
    access_token: str = Form(...),
    video: UploadFile = File(...),
    title: str = Form(...),
    description: str = Form(...),
    file: UploadFile = None
):
    if file is None:
        return JSONResponse({"error": "No file provided"}, status_code=400)
    
    # save file temp
    temp_path = f"/tmp/{file.filename}"
    with open(temp_path, "wb") as f:
        f.write(file.file.read())
    
    # check if video is short
    try:
        result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", temp_path], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        duration = float(result.stdout)
        if duration > 60:
            os.remove(temp_path)
            return JSONResponse({"error": "Video is too long"}, status_code=400)
    except Exception:
        pass

    try:
        # create youtube client
        youtube = build("youtube", "v3", developerKey=None, credentials=None)

        # set access token
        youtube._http.headers.update({"Authorization": f"Bearer {access_token}"})

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
