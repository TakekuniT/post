import os
import requests
import time
from datetime import datetime, timedelta, timezone
from utils.db_client import UserManager

class LinkedInService:
    @staticmethod
    def get_valid_token(user_id: str):
        """
        Retrieves and refreshes the LinkedIn 3-legged access token.
        LinkedIn tokens typically last 60 days.
        """
        account = UserManager.get_social_tokens(user_id, "linkedin")
        if not account:
            raise Exception("LinkedIn account not linked.")

        # Standardizing timezone check
        expires_at_str = account["expires_at"].replace('Z', '+00:00')
        expires_at = datetime.fromisoformat(expires_at_str)

        # Refresh if token expires in less than 5 days
        if datetime.now(timezone.utc) + timedelta(days=5) > expires_at:
            # Note: Programmatic refresh requires the 'offline_access' scope
            if not account.get("refresh_token"):
                raise Exception("LinkedIn Token Expired: Please re-authenticate (no refresh token).")
            
            print(f"Refreshing LinkedIn token for {user_id}...")
            url = "https://www.linkedin.com/oauth/v2/accessToken"
            data = {
                "grant_type": "refresh_token",
                "refresh_token": account["refresh_token"],
                "client_id": os.getenv("LINKEDIN_CLIENT_ID"),
                "client_secret": os.getenv("LINKEDIN_CLIENT_SECRET"),
            }
            res = requests.post(url, data=data).json()
            
            if "access_token" not in res:
                raise Exception(f"LinkedIn Refresh Failed: {res}")

            new_expiry = datetime.now(timezone.utc) + timedelta(seconds=res.get("expires_in", 5184000))
            UserManager.update_social_account(user_id, "linkedin", {
                "access_token": res["access_token"],
                "refresh_token": res.get("refresh_token"), # May be a new one
                "expires_at": new_expiry.isoformat()
            })
            return res["access_token"], account["platform_user_id"]

        return account["access_token"], account["platform_user_id"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        """
        LinkedIn Multi-part Video Upload Engine.
        """
        try:
            print(f"[LinkedIn Upload] Starting upload...")
            token, person_urn = LinkedInService.get_valid_token(user_id)
            file_size = os.path.getsize(file_path)
            headers = {
                "Authorization": f"Bearer {token}",
                "X-Restli-Protocol-Version": "2.0.0",
                "LinkedIn-Version": "202511", # Use current stable version
                "Content-Type": "application/json"
            }

            # --- PHASE 1: INITIALIZE UPLOAD ---
            init_url = "https://api.linkedin.com/rest/videos?action=initializeUpload"
            init_data = {
                "initializeUploadRequest": {
                    "owner": f"urn:li:person:{person_urn}",
                    "fileSizeBytes": file_size,
                    "uploadThumbnail": False
                }
            }
            init_res = requests.post(init_url, json=init_data, headers=headers).json()
            
            value = init_res.get("value")
            if not value:
                raise Exception(f"LinkedIn Init Failed: {init_res}")

            video_urn = value["video"]
            upload_token = value["uploadToken"]
            upload_instructions = value["uploadInstructions"]
            print(f"[LinkedIn Upload] Session initialized. Video URN: {video_urn}")

            # --- PHASE 2: UPLOAD PARTS ---
            # LinkedIn provides specific byte ranges for chunks
            uploaded_part_ids = []
            with open(file_path, "rb") as f:
                for instruction in upload_instructions:
                    first_byte = instruction["firstByte"]
                    last_byte = instruction["lastByte"]
                    upload_url = instruction["uploadUrl"]
                    
                    # Read the specific chunk
                    f.seek(first_byte)
                    chunk_data = f.read(last_byte - first_byte + 1)
                    
                    # Upload using PUT (no Auth header for the upload link itself)
                    chunk_res = requests.put(upload_url, data=chunk_data)
                    
                    # Capture ETag for finalization
                    etag = chunk_res.headers.get("ETag")
                    if not etag:
                        raise Exception("Failed to get ETag for video part")
                    uploaded_part_ids.append(etag)
                    print(f"[LinkedIn Upload] Part {first_byte}-{last_byte} uploaded.")

            # --- PHASE 3: FINALIZE UPLOAD ---
            finalize_url = "https://api.linkedin.com/rest/videos?action=finalizeUpload"
            finalize_data = {
                "finalizeUploadRequest": {
                    "video": video_urn,
                    "uploadToken": upload_token,
                    "uploadedPartIds": uploaded_part_ids
                }
            }
            requests.post(finalize_url, json=finalize_data, headers=headers)
            print("[LinkedIn Upload] Finalization request sent.")

            # --- PHASE 4: CREATE THE POST (SHARE) ---
            # We wait a moment for LinkedIn to process the video asset
            time.sleep(5) 
            post_url = "https://api.linkedin.com/rest/posts"
            post_data = {
                "author": f"urn:li:person:{person_urn}",
                "commentary": caption,
                "visibility": "PUBLIC",
                "distribution": {
                    "feedDistribution": "MAIN_FEED",
                    "targetEntities": [],
                    "thirdPartyDistributionChannels": []
                },
                "content": {
                    "media": {
                        "id": video_urn
                    }
                },
                "lifecycleState": "PUBLISHED"
            }
            post_res = requests.post(post_url, json=post_data, headers=headers)
            
            if post_res.status_code != 201:
                raise Exception(f"LinkedIn Posting Failed: {post_res.text}")

            print(f"[LinkedIn Upload] Success! Post created for {video_urn}")

           
            if post_res.status_code == 201:
            # Get the ID from the header (e.g., "urn:li:share:123456789")
                post_urn = post_res.headers.get("x-restli-id")
                
                if post_urn:
                    # Extract the numeric ID
                    post_id = post_urn.split(":")[-1]
                    
                    # TRY THIS FORMAT: It works for both Activity and Share IDs
                    share_url = f"https://www.linkedin.com/feed/update/urn:li:ugcPost:{post_id}"
                    
                    print(f"[LinkedIn] Link: {share_url}")
                    return {"platform": "linkedin", "url": share_url}

        except Exception as e:
            print(f"[LinkedIn Service Error] {str(e)}")
            return None