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
            print("[Token Check] No TikTok account found.")
            raise Exception("TikTok account not linked.")

        # 1. Parse the expiry date safely
        try:
            expires_at_str = account.get("expires_at", "")
            expires_at = datetime.fromisoformat(expires_at_str.replace('Z', '+00:00'))
        except Exception as e:
            print(f"[Token Check] Date parsing error: {str(e)}")
            raise Exception("Invalid token date format in database.")

        # 2. Check if token is expired (or expires in the next 10 minutes)
        if datetime.now(timezone.utc) + timedelta(minutes=10) > expires_at:
            print("[Token Check] Token expired. Refreshing...")
            
            url = "https://open.tiktokapis.com/v2/oauth/token/"
            data = {
                "client_key": os.getenv("TIKTOK_CLIENT_ID"),
                "client_secret": os.getenv("TIKTOK_CLIENT_SECRET"),
                "grant_type": "refresh_token",
                "refresh_token": account.get("refresh_token")
            }
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
            
            response = requests.post(url, data=data, headers=headers)
            res_json = response.json()
            
            # 3. Handle Refresh Success
            if "access_token" in res_json:
                print("[Token Check] Refresh successful. Saving new tokens...")
                
                # TikTok often sends a NEW refresh_token. You MUST save it.
                new_access_token = res_json["access_token"]
                new_refresh_token = res_json.get("refresh_token", account["refresh_token"])
                
                # Calculate new expiry (TikTok access tokens are usually 86400 seconds / 24h)
                expires_in = res_json.get("expires_in", 86400)
                new_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
                
                # 4. Update the database with BOTH new tokens
                update_payload = {
                    "access_token": new_access_token,
                    "refresh_token": new_refresh_token, 
                    "expires_at": new_expiry.isoformat()
                }
                UserManager.update_social_account(user_id, "tiktok", update_payload)
                
                return new_access_token
            else:
                # 5. Handle Critical Failure (Invalid Grant)
                error_msg = res_json.get("error_description") or res_json.get("error", "Unknown error")
                print(f"[Token Check] CRITICAL: Refresh failed. {error_msg}")
                
                # If the refresh token itself is dead, we can't do anything but re-link
                if "invalid_grant" in str(res_json):
                    print("RE-AUTHENTICATION REQUIRED: The refresh token is dead.")
                
                raise Exception(f"TikTok Refresh Failed: {error_msg}")

        print("[Token Check] Current token is still valid.")
        return account["access_token"]
    # @staticmethod
    # async def upload_video(user_id: str, file_path: str, caption: str):
    #     print(f"DEBUG: Starting TikTok Upload...")
    #     try:
    #         print(f"DEBUG: Uploading {caption} to TikTok...")
    #         token = TikTokService.get_valid_token(user_id)
    #         video_size = os.path.getsize(file_path)
            
    #         # Use 5MB chunks for better stability
    #         chunk_size = 5 * 1024 * 1024 
    #         total_chunks = math.ceil(video_size / chunk_size)
    #         if video_size < 50 * 1024 * 1024:
    #             chunk_size = video_size
    #             total_chunks = 1
    #         else:
    #             # Fallback for very large files
    #             chunk_size = 10 * 1024 * 1024
    #             total_chunks = math.ceil(video_size / chunk_size)

    #         print(f"DEBUG: Total Chunks: {total_chunks}")
    #         print(f"[Upload] File size: {video_size} | Chunk size: {chunk_size} | Total: {total_chunks}")
    #         # --- STEP 1: INITIALIZE ---
    #         # TikTok now prefers 'video.upload' scope
    #         init_url = "https://open.tiktokapis.com/v2/post/publish/video/init/"
    #         headers = {
    #             "Authorization": f"Bearer {token}",
    #             "Content-Type": "application/json; charset=UTF-8"
    #         }
            
    #         # Quality Tip: TikTok likes titles without too many special chars in the init phase
    #         body = {
    #             "post_info": {
    #                 "title": caption[:50],
    #                 "privacy_level": "SELF_ONLY" 
    #             },
    #             "source_info": {
    #                 "source": "FILE_UPLOAD",
    #                 "video_size": video_size,
    #                 "chunk_size": chunk_size,
    #                 "total_chunk_count": total_chunks
    #             }
    #         }
            
    #         response = requests.post(init_url, json=body, headers=headers)
    #         print(f"DEBUG: Status Code: {response.status_code}")
    #         print(f"DEBUG: Response Body: {response.text}")
    #         init_res = response.json()
            
    #         # --- DEBUGGING LINE ---
    #         if "data" not in init_res:
    #             print(f"DEBUG: TikTok Full Error Response: {init_res}")
    #             raise Exception(f"Init Error: {init_res.get('error', {}).get('message', 'Unknown Error')}")

    #         publish_id = init_res["data"]["publish_id"]
    #         upload_url = init_res["data"]["upload_url"]

    #         # --- STEP 2: CHUNKED UPLOAD ---
            
    #         with open(file_path, "rb") as f:
    #             for i in range(total_chunks):
    #                 chunk_data = f.read(chunk_size)
    #                 start_byte = i * chunk_size
    #                 end_byte = start_byte + len(chunk_data) - 1
                    
    #                 put_headers = {
    #                     "Content-Type": "video/mp4",
    #                     "Content-Range": f"bytes {start_byte}-{end_byte}/{video_size}"
    #                 }
                    
    #                 res = requests.put(upload_url, data=chunk_data, headers=put_headers)
                    
    #                 if res.status_code not in [200, 201, 206]:
    #                     raise Exception(f"Chunk {i} fail: {res.status_code}")
                    
    #                 print(f"TikTok: {int(((i+1)/total_chunks)*100)}% Uploaded")

    #         return publish_id

    #     except Exception as e:
    #         print(f"TikTok Service Detailed Error: {str(e)}")
    #         return None
    
    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        try:
            print(f"DEBUG: Starting TikTok Upload for {caption}")
            token = TikTokService.get_valid_token(user_id)
            
            video_size = os.path.getsize(file_path)
            
            # For files under 64MB, ALWAYS use 1 chunk. 
            # This eliminates math errors with TikTok's validator.
            if video_size < 64 * 1024 * 1024:
                chunk_size = video_size
                total_chunks = 1
            else:
                # For large files, use 10MB chunks
                chunk_size = 10 * 1024 * 1024
                total_chunks = math.ceil(video_size / chunk_size)

            print(f"[Upload] File: {video_size} | Chunk: {chunk_size} | Count: {total_chunks}")

            # STEP 1: Initialize upload
            init_url = "https://open.tiktokapis.com/v2/post/publish/video/init/"
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json; charset=UTF-8"
            }
            
            body = {
                "post_info": {
                    "title": caption[:50],
                    "privacy_level": "SELF_ONLY"
                },
                "source_info": {
                    "source": "FILE_UPLOAD",
                    "video_size": int(video_size),
                    "chunk_size": int(chunk_size),
                    "total_chunk_count": int(total_chunks)
                }
            }
            
            response = requests.post(init_url, json=body, headers=headers)
            init_res = response.json()
            
            if "data" not in init_res:
                print(f"DEBUG: TikTok Init Failed. Full Response: {init_res}")
                raise Exception(f"Init Error: {init_res.get('error', {}).get('message', 'Unknown Error')}")

            publish_id = init_res["data"]["publish_id"]
            upload_url = init_res["data"]["upload_url"]

            # STEP 2: Chunked upload
            with open(file_path, "rb") as f:
                for i in range(total_chunks):
                    start_byte = i * chunk_size
                    f.seek(start_byte)
                    chunk_data = f.read(chunk_size)
                    
                    actual_read_size = len(chunk_data)
                    end_byte = start_byte + actual_read_size - 1

                    put_headers = {
                        "Content-Type": "video/mp4",
                        "Content-Range": f"bytes {start_byte}-{end_byte}/{video_size}"
                    }

                    # TikTok upload_url is a pre-signed S3-style URL; it doesn't need the Bearer token
                    res = requests.put(upload_url, data=chunk_data, headers=put_headers)

                    if res.status_code not in [200, 201, 206]:
                        print(f"DEBUG: Chunk {i} failed. Status: {res.status_code} Body: {res.text}")
                        raise Exception(f"Chunk {i} failed: {res.status_code}")

                    print(f"TikTok: {int(((i+1)/total_chunks)*100)}% Uploaded")

            print(f"TikTok upload complete! Publish ID: {publish_id}")
            return publish_id

        except Exception as e:
            print(f"TikTok Service Detailed Error: {str(e)}")
            return None