import os
import requests
import math
from datetime import datetime, timedelta
from utils.supabase import UserManager

class TikTokService:
    @staticmethod
    def get_valid_token(user_id: str):
        """
        Ensures a working access token by checking expiry and refreshing if needed.
        """
        account = UserManager.get_social_tokens(user_id, "tiktok")
        if not account:
            raise Exception("TikTok account not linked for this user.")

        expires_at = datetime.fromisoformat(account["expires_at"])
        if datetime.utcnow() + timedelta(minutes=5) > expires_at:
            print(f"Refreshing TikTok token for {user_id}...")
            
            url = "https://open.tiktokapis.com/v2/oauth/token/"
            data = {
                "client_key": os.getenv("TIKTOK_CLIENT_ID"),
                "client_secret": os.getenv("TIKTOK_CLIENT_SECRET"),
                "grant_type": "refresh_token",
                "refresh_token": account["refresh_token"]
            }
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            
            response = requests.post(url, data=data, headers=headers).json()
            
            if "access_token" not in response:
                raise Exception(f"TikTok refresh failed: {response}")

            new_expiry = datetime.utcnow() + timedelta(seconds=response["expires_in"])
            update_data = {
                "access_token": response["access_token"],
                "refresh_token": response.get("refresh_token", account["refresh_token"]),
                "expires_at": new_expiry.isoformat()
            }
            UserManager.save_social_account(user_id, "tiktok", update_data)
            return response["access_token"]

        return account["access_token"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        """
        High-Quality Upload Engine: Uses chunked transfers to preserve bitrate.
        """
        try:
            token = TikTokService.get_valid_token(user_id)
            video_size = os.path.getsize(file_path)
            
            # 10MB chunks are optimal for TikTok's ingest servers
            chunk_size = 10 * 1024 * 1024 
            total_chunks = math.ceil(video_size / chunk_size)

            # --- STEP 1: INITIALIZE ---
            init_url = "https://open.tiktokapis.com/v2/post/publish/video/init/"
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
            body = {
                "post_info": {
                    "title": caption[:50],
                    "privacy_level": "SELF_ONLY", # Change to "SELF_ONLY" for sandbox testing, change to "PUBLIC_TO_ANYONE" for production
                    "video_cover_timestamp_ms": 1000 # Sets cover at 1 second
                },
                "source_info": {
                    "source": "FILE_UPLOAD",
                    "video_size": video_size,
                    "chunk_size": chunk_size,
                    "total_chunk_count": total_chunks
                }
            }
            
            init_res = requests.post(init_url, json=body, headers=headers).json()
            if "data" not in init_res:
                raise Exception(f"TikTok Init Failed: {init_res}")

            publish_id = init_res["data"]["publish_id"]
            upload_url = init_res["data"]["upload_url"]

            # --- STEP 2: CHUNKED UPLOAD ---
            
            with open(file_path, "rb") as f:
                for i in range(total_chunks):
                    chunk_data = f.read(chunk_size)
                    start_byte = i * chunk_size
                    end_byte = start_byte + len(chunk_data) - 1
                    
                    put_headers = {
                        "Content-Type": "video/mp4",
                        "Content-Length": str(len(chunk_data)),
                        "Content-Range": f"bytes {start_byte}-{end_byte}/{video_size}"
                    }
                    
                    # Uploading chunk
                    res = requests.put(upload_url, data=chunk_data, headers=put_headers)
                    
                    if res.status_code not in [200, 206]:
                        raise Exception(f"Chunk {i} failed with status {res.status_code}: {res.text}")
                    
                    print(f"User {user_id}: Uploaded chunk {i+1}/{total_chunks}")

            print(f"Successfully posted to TikTok. Publish ID: {publish_id}")
            return publish_id

        except Exception as e:
            print(f"TikTok Service Error: {str(e)}")
            return None