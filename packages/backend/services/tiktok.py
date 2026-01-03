import os
import requests
import math
from datetime import datetime, timedelta, timezone
from utils.db_client import UserManager

class TikTokService:
    @staticmethod
    def get_valid_token(user_id: str):
        print(f"[Token Check] Fetching tokens for user: {user_id}")
        account = UserManager.get_social_tokens(user_id, "tiktok")
        
        if not account:
            print("[Token Check] No TikTok account found in database.")
            raise Exception("TikTok account not linked.")

        # Handle potential date formatting issues from Supabase
        try:
            expires_at_str = account.get("expires_at", "")
            if not expires_at_str:
                raise Exception("Field 'expires_at' is missing in database row.")
                
            expires_at = datetime.fromisoformat(expires_at_str.replace('Z', '+00:00'))
        except Exception as e:
            print(f"[Token Check] Date parsing error: {str(e)}")
            raise Exception(f"Invalid date format in DB: {str(e)}")

        # Check if token expires within the next 5 minutes
        if datetime.now(timezone.utc) + timedelta(minutes=5) > expires_at:
            print("[Token Check] Token expired or nearly expired. Refreshing...")
            
            client_id = os.getenv("TIKTOK_CLIENT_ID")
            client_secret = os.getenv("TIKTOK_CLIENT_SECRET")
            
            if not client_id or not client_secret:
                print("[Token Check] Missing TikTok credentials in .env file.")
                raise Exception("Missing TIKTOK_CLIENT_ID or TIKTOK_CLIENT_SECRET")

            url = "https://open.tiktokapis.com/v2/oauth/token/"
            data = {
                "client_key": client_id,
                "client_secret": client_secret,
                "grant_type": "refresh_token",
                "refresh_token": account.get("refresh_token")
            }
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            
            response = requests.post(url, data=data, headers=headers)
            res_json = response.json()
            
            if "access_token" not in res_json:
                print(f"[Token Check] Refresh failed: {res_json}")
                # Capturing the actual error from TikTok response
                error_msg = res_json.get("error_description") or res_json.get("error", "Unknown error")
                raise Exception(f"TikTok Refresh Failed: {error_msg}")

            print("[Token Check] Refresh successful. Updating database...")
            
            expires_in = res_json.get("expires_in", 86400) # Default 24h if missing
            new_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
            
            update_payload = {
                "access_token": res_json["access_token"],
                "refresh_token": res_json.get("refresh_token", account["refresh_token"]),
                "expires_at": new_expiry.isoformat()
            }
            UserManager.save_social_account(user_id, "tiktok", update_payload)
            return res_json["access_token"]

        print("[Token Check] Current token is still valid.")
        return account["access_token"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        print(f"DEBUG: Starting TikTok Upload...")
        try:
            print(f"DEBUG: Uploading {caption} to TikTok...")
            token = TikTokService.get_valid_token(user_id)
            video_size = os.path.getsize(file_path)
            
            # Use 5MB chunks for better stability
            chunk_size = 10 * 1024 * 1024 
            total_chunks = math.ceil(video_size / chunk_size)
            if video_size < 50 * 1024 * 1024:
                chunk_size = video_size
                total_chunks = 1
            else:
                # Fallback for very large files
                chunk_size = 10 * 1024 * 1024
                total_chunks = math.ceil(video_size / chunk_size)

            print(f"DEBUG: Total Chunks: {total_chunks}")
            print(f"[Upload] File size: {video_size} | Chunk size: {chunk_size} | Total: {total_chunks}")
            # --- STEP 1: INITIALIZE ---
            # TikTok now prefers 'video.upload' scope
            init_url = "https://open.tiktokapis.com/v2/post/publish/video/init/"
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json; charset=UTF-8"
            }
            
            # Quality Tip: TikTok likes titles without too many special chars in the init phase
            body = {
                "post_info": {
                    "title": caption[:50],
                    "privacy_level": "SELF_ONLY" 
                },
                "source_info": {
                    "source": "FILE_UPLOAD",
                    "video_size": video_size,
                    "chunk_size": chunk_size,
                    "total_chunk_count": total_chunks
                }
            }
            
            response = requests.post(init_url, json=body, headers=headers)
            print(f"DEBUG: Status Code: {response.status_code}")
            print(f"DEBUG: Response Body: {response.text}")
            init_res = response.json()
            
            # --- DEBUGGING LINE ---
            if "data" not in init_res:
                print(f"DEBUG: TikTok Full Error Response: {init_res}")
                raise Exception(f"Init Error: {init_res.get('error', {}).get('message', 'Unknown Error')}")

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
                        "Content-Range": f"bytes {start_byte}-{end_byte}/{video_size}"
                    }
                    
                    res = requests.put(upload_url, data=chunk_data, headers=put_headers)
                    
                    if res.status_code not in [200, 201, 206]:
                        raise Exception(f"Chunk {i} fail: {res.status_code}")
                    
                    print(f"TikTok: {int(((i+1)/total_chunks)*100)}% Uploaded")

            return publish_id

        except Exception as e:
            print(f"TikTok Service Detailed Error: {str(e)}")
            return None