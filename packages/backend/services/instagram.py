import os
import requests
import time
from utils.db_client import UserManager
from datetime import datetime, timedelta, timezone
from utils.db_client import supabase

class InstagramService:
    @staticmethod
    def get_public_url(bucket: str, path: str) -> str:
        res = supabase.storage.from_(bucket).get_public_url(path)
        return res
   
    @staticmethod
    def wait_for_media_ready(media_id: str, token: str, timeout=60):
        """
        Instagram fetches media asynchronously.
        We MUST wait until status_code == FINISHED.
        """
        status_url = f"https://graph.facebook.com/v19.0/{media_id}"
        start = time.time()

        while time.time() - start < timeout:
            res = requests.get(
                status_url,
                params={"fields": "status_code", "access_token": token}
            ).json()

            status = res.get("status_code")
            print(f"[DEBUG] IG media {media_id} status:", status)

            if status == "FINISHED":
                return True
            if status == "ERROR":
                raise Exception(f"Instagram processing error: {res}")

            time.sleep(3)

        raise TimeoutError("Instagram media processing timed out")
    
    @staticmethod
    def get_valid_token(user_id: str):
        """
        Ensures the Instagram Long-Lived token is still valid.
        If it's older than 45 days, we refresh it for another 60 days.
        """
        account = UserManager.get_social_tokens(user_id, "instagram")
        if not account:
            raise Exception("Instagram account not linked.")

        # 1. Check if the token needs refreshing
        # We refresh once it's within 15 days of expiring (45 days old)
        expires_at_str = account["expires_at"].replace('Z', '+00:00')
        expires_at = datetime.fromisoformat(expires_at_str)
        if datetime.now(timezone.utc) + timedelta(days=15) > expires_at:
            print(f"Instagram token for {user_id} is getting old. Refreshing...")

            # 2. Exchange old long-lived token for a NEW long-lived token
            # endpoint: GET /oauth/access_token
            url = "https://graph.facebook.com/v19.0/oauth/access_token"
            params = {
                "grant_type": "fb_exchange_token",
                "client_id": os.getenv("INSTAGRAM_CLIENT_ID"),
                "client_secret": os.getenv("INSTAGRAM_CLIENT_SECRET"),
                "fb_exchange_token": account["access_token"]
            }
            
            response = requests.get(url, params=params).json()
            
            if "access_token" not in response:
                raise Exception(f"Instagram Token Refresh Failed: {response}")

            # 3. Save the new 60-day token to Supabase
            # expires_in is usually 5184000 seconds (60 days)
            new_expiry = datetime.utcnow() + timedelta(seconds=response.get("expires_in", 5184000))
            
            update_data = {
                "access_token": response["access_token"],
                "expires_at": new_expiry.isoformat()
            }
            UserManager.update_social_account(user_id, "instagram", update_data)
            
            return response["access_token"], account["platform_user_id"]

        return account["access_token"], account["platform_user_id"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        """
        High-Quality Resumable Upload for Instagram Reels.
        """
        try:
            token, ig_user_id = InstagramService.get_valid_token(user_id)
            file_size = os.path.getsize(file_path)

            # --- STEP 1: Create a Media Container ---
            # We tell Instagram we are sending a REEL
            init_url = f"https://graph.facebook.com/v19.0/{ig_user_id}/media"
            params = {
                "media_type": "REELS",
                "caption": caption,
                "upload_type": "resumable",
                "access_token": token
            }
            init_res = requests.post(init_url, params=params).json()
            
            if "id" not in init_res:
                raise Exception(f"Instagram Init Failed: {init_res}")
            
            container_id = init_res["id"]

            # --- STEP 2: Upload the Bytes (Resumable) ---
            # Instagram uses a specific 'rupload' host for pushing binaries
            upload_url = f"https://rupload.facebook.com/ig-api-upload/{container_id}"

            with open(file_path, "rb") as f:
                headers = {
                    "Authorization": f"Bearer {token}",
                    "offset": "0",
                    "file_size": str(file_size),
                    "Content-Type": "application/octet-stream"
                }
                response = requests.post(upload_url, data=f, headers=headers)
                upload_res = response.json()

            # Fix: Instagram resumable upload returns {'success': True} 
            # instead of {'status': 'success'}
            if not upload_res.get("success"):
                raise Exception(f"Instagram Bytes Upload Failed: {upload_res}")
            
            print("Bytes uploaded to Instagram. Starting processing wait...")


           
            # --- STEP 3: Wait for Processing ---
            # Instagram must process the video before it can be published.
            # We check the status every few seconds.
            
            
            status_url = f"https://graph.facebook.com/v19.0/{container_id}"
            max_retries = 30
            for _ in range(max_retries):
                check = requests.get(status_url, params={"fields": "status_code", "access_token": token}).json()
                status = check.get("status_code")
                
                if status == "FINISHED":
                    break
                elif status == "ERROR":
                    raise Exception("Instagram processing failed.")
                
                time.sleep(5)

            # --- STEP 4: Finalize & Publish ---
            publish_url = f"https://graph.facebook.com/v19.0/{ig_user_id}/media_publish"
            publish_res = requests.post(publish_url, params={
                "creation_id": container_id,
                "access_token": token
            }).json()

            print(f"Successfully posted to Instagram! Media ID: {publish_res.get('id')}")
            media_id= publish_res.get("id")

            if not media_id:
                raise Exception("Failed to get Media ID after publishing")

            # --- STEP 5: Fetch the Permalink ---
            # We query the newly created Media ID to get its public URL
            media_info_url = f"https://graph.facebook.com/v19.0/{media_id}"
            media_info = requests.get(media_info_url, params={
                "fields": "permalink",
                "access_token": token
            }).json()

            ig_url = media_info.get("permalink")

            # If for some reason permalink fails, we fallback to a standard ID link
            if not ig_url:
                ig_url = f"https://www.instagram.com/reels/{media_id}/"

            print(f"Successfully posted to Instagram! Link: {ig_url}")
            
            return {"platform": "instagram", "url": ig_url}

        except Exception as e:
            print(f"Instagram Service Error: {str(e)}")
            return None
        
    @staticmethod
    async def upload_photos(user_id: str, supabase_paths: list[str], caption: str):
        """
        Upload photos (single or carousel) to Instagram using Supabase-hosted images.
        """

        token, ig_user_id = InstagramService.get_valid_token(user_id)
        bucket = "photos"

        try:
            # --------------------------------------------
            # STEP 1: Supabase paths → public URLs
            # --------------------------------------------
            image_urls = [
                InstagramService.get_public_url(bucket, path)
                for path in supabase_paths
            ]

            # --------------------------------------------
            # STEP 2: Create image containers
            # --------------------------------------------
            media_ids = []

            for url in image_urls:
                res = requests.post(
                    f"https://graph.facebook.com/v19.0/{ig_user_id}/media",
                    params={
                        "image_url": url,
                        "is_carousel_item": "true" if len(image_urls) > 1 else "false",
                        "access_token": token,
                    },
                ).json()

                print("[DEBUG] IG image init:", res)

                if "id" not in res:
                    raise Exception(f"Image container creation failed: {res}")

                media_id = res["id"]
                media_ids.append(media_id)

            # --------------------------------------------
            # STEP 3: WAIT for each image to finish
            # --------------------------------------------
            for media_id in media_ids:
                InstagramService.wait_for_media_ready(media_id, token)

            # --------------------------------------------
            # STEP 4: Create final container
            # --------------------------------------------
            if len(media_ids) == 1:
                final_creation_id = media_ids[0]

                requests.post(
                    f"https://graph.facebook.com/v19.0/{final_creation_id}",
                    params={"caption": caption, "access_token": token},
                )

            else:
                carousel = requests.post(
                    f"https://graph.facebook.com/v19.0/{ig_user_id}/media",
                    params={
                        "media_type": "CAROUSEL",
                        "children": ",".join(media_ids),
                        "caption": caption,
                        "access_token": token,
                    },
                ).json()

                print("[DEBUG] Carousel init:", carousel)

                if "id" not in carousel:
                    raise Exception(f"Carousel creation failed: {carousel}")

                final_creation_id = carousel["id"]

                InstagramService.wait_for_media_ready(final_creation_id, token)

            # --------------------------------------------
            # STEP 5: Publish
            # --------------------------------------------
            publish = requests.post(
                f"https://graph.facebook.com/v19.0/{ig_user_id}/media_publish",
                params={"creation_id": final_creation_id, "access_token": token},
            ).json()

            if "id" not in publish:
                raise Exception(f"Publish failed: {publish}")

            media_id = publish["id"]

            # --------------------------------------------
            # STEP 6: Get permalink
            # --------------------------------------------
            permalink = requests.get(
                f"https://graph.facebook.com/v19.0/{media_id}",
                params={"fields": "permalink", "access_token": token},
            ).json().get("permalink")

            return {"platform": "instagram", "url": permalink}

        except Exception as e:
            print("[IG Photo Error]", str(e))
            return None