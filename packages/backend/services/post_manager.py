import asyncio
from services.youtube import YouTubeService
from services.tiktok import TikTokService
from services.instagram import InstagramService
from services.facebook import FacebookService
from services.linkedin import LinkedInService

class PostManager:
    @staticmethod
    async def distribute_video(user_id: str, file_path: str, caption: str, description: str, platforms: list):
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
        return results