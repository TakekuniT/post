import asyncio
from services.youtube_service import YouTubeService
from services.tiktok_service import TikTokService
from services.instagram_service import InstagramService
from services.facebook_service import FacebookService

class PostManager:
    @staticmethod
    async def distribute_video(user_id: str, file_path: str, caption: str, title: str, platforms: list):
        """
        Coordinates multi-platform uploads.
        """
        tasks = []
        
        if "youtube" in platforms:
            tasks.append(YouTubeService.upload_video(user_id, file_path, caption, title))
            
        if "tiktok" in platforms:
            tasks.append(TikTokService.upload_video(user_id, file_path, caption))
            
        if "instagram" in platforms:
            tasks.append(InstagramService.upload_video(user_id, file_path, caption))
    
        if "facebook" in platforms:
            tasks.append(FacebookService.upload_video(user_id, file_path, caption))
        
        # Run all uploads at the same time!
        results = await asyncio.gather(*tasks, return_exceptions=True)
        return results