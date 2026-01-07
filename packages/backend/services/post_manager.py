import asyncio
from services.youtube import YouTubeService
from services.tiktok import TikTokService
from services.instagram import InstagramService
from services.facebook import FacebookService
from services.linkedin import LinkedInService
from utils.db_client import supabase
from services.subscription_service import SubscriptionService
import os

class PostManager:
    @staticmethod
    async def distribute_video(post_id: str, user_id: str, file_path: str, caption: str, description: str, platforms: list):
        try:
            """
            Coordinates multi-platform uploads.
            """
            tasks = []
            user_perms = await SubscriptionService.get_user_permissions(user_id, supabase)
            requested_platforms = len(platforms)

            if requested_platforms > user_perms["max_platforms"]:
                return {"error": f"Upgrade to reach more than {user_perms['max_platforms']} platforms."}
            
            if not user_perms["non_branded_caption"]:
                caption += "\nSent via UniPost on iOS #unipost #poweredbyunipost"

            if "youtube" in platforms:
                tasks.append(YouTubeService.upload_video(user_id, file_path, caption, description))
                
            if "tiktok" in platforms:
                tasks.append(TikTokService.upload_video(user_id, file_path, caption))
                
            if "instagram" in platforms:
                tasks.append(InstagramService.upload_video(user_id, file_path, caption))
        
            if "facebook" in platforms:
                tasks.append(FacebookService.upload_video(user_id, file_path, caption))
            
            if "linkedin" in platforms:
                tasks.append(LinkedInService.upload_video(user_id, file_path, caption))

            # Run all uploads at the same time!
            results = await asyncio.gather(*tasks, return_exceptions=True)

            links_to_save = {}
            for res in results:
                if isinstance(res, dict) and res.get("url"):
                    links_to_save[res["platform"]] = res["url"]

            # Update the row in Supabase using the post_id
            if links_to_save:
                supabase.table("posts").update({
                    "platform_links": links_to_save
                }).eq("id", post_id).execute()


            return results
        finally:
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"DEBUG: Removed local file {file_path}")

            
            file_name = os.path.basename(file_path)
            try:
                supabase.storage.from_("videos").remove([file_name])
                print(f"DEBUG: Removed {file_name} from Supabase Storage")
            except Exception as e:
                print(f"Cleanup Error: {str(e)}")