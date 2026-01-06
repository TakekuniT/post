import asyncio
from services.youtube import YouTubeService
from services.tiktok import TikTokService
from services.instagram import InstagramService
from services.facebook import FacebookService
from services.linkedin import LinkedInService
from utils.db_client import supabase

class PostManager:
    @staticmethod
    async def distribute_video(post_id: str,user_id: str, file_path: str, caption: str, description: str, platforms: list):
        """
        Coordinates multi-platform uploads.
        """
        tasks = []
        
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