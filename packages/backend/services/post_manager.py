import asyncio
from services.youtube import YouTubeService
from services.tiktok import TikTokService
from services.instagram import InstagramService
from services.facebook import FacebookService
from services.linkedin import LinkedInService
from utils.db_client import supabase
from services.subscription_service import SubscriptionService
import os
from utils.video_processor import VideoProcessor


class PostManager:
    @staticmethod
    async def distribute_photos(post_id: str, user_id: str, file_paths: list, caption: str, platforms: list):
       
        supabase_paths = [] # may be watermarked paths
        original_supabase_paths = [] # non-watermarked paths
        full_supabase_paths = [] # full directory paths
        print("[DEBUG] distribute photos")
        
        for path in file_paths:
            full_supabase_paths.append(path)
            supabase_path = os.path.basename(path)
            original_supabase_paths.append(supabase_path)
            supabase_paths.append(supabase_path)
        try:
            tasks = []
            print("[DEBUG] getting user perms")
            user_perms = await SubscriptionService.get_user_permissions(user_id, supabase)
            requested_platforms = len(platforms)
            print(f"DEBUG: User perms for watermark: {user_perms.get('no_watermark')}")

            if not user_perms.get("no_watermark", False):
                full_supabase_paths = VideoProcessor.add_photo_watermark(file_paths)
                supabase_paths = [path.replace(".jpg", "_watermarked.jpg") for path in supabase_paths]
                
                print(f"DEBUG: Watermarking complete. New paths: {supabase_paths}")
            else:
                print(f"DEBUG: Watermarking skipped. Paths: {supabase_paths}")
            if requested_platforms > user_perms["max_platforms"]:
                return {"error": f"Upgrade to reach more than {user_perms['max_platforms']} platforms."}
            
            user_perms = await SubscriptionService.get_user_permissions(user_id, supabase)
            if not user_perms["non_branded_caption"]:
                caption += "\nPosted via UniCore on iOS #unicore #poweredbyunicore"

            print(f"DEBUG: supabse_paths: {supabase_paths}")
            print(f"DEBUG: file_paths: {file_paths}")
            print(f"DEBUG: full_supabase_paths: {full_supabase_paths}")
            if "instagram" in platforms:
                print(f"DEBUG: Instagram uploading...")
                print(f"platforms: {platforms}")
                tasks.append(InstagramService.upload_photos(user_id, full_supabase_paths, caption))

            if "facebook" in platforms:
                tasks.append(FacebookService.upload_photos(user_id, full_supabase_paths, caption))

            if "linkedin" in platforms:
                tasks.append(LinkedInService.upload_photos(user_id, full_supabase_paths, caption))
            
            # Run all uploads at the same time!
            results = await asyncio.gather(*tasks, return_exceptions=True)

            links_to_save = {}
            for res in results:
                if isinstance(res, dict) and res.get("url"):
                    links_to_save[res["platform"]] = res["url"]

            # Update the row in Supabase using the post_id
            if links_to_save:
                supabase.table("posts").update({
                    "platform_links": links_to_save,
                    "status": "published" # added
                }).eq("id", post_id).execute()


            return results
        except Exception as e:
            print(f"Error: {str(e)}")
            import traceback
            traceback.print_exc()
        finally:
            for path in file_paths: # removes the original local files
                if os.path.exists(path):
                    os.remove(path)
                    print(f"DEBUG: Removed local file {path}")
            for path in full_supabase_paths: # removes the watermarked supabase files
                if os.path.exists(path):
                    os.remove(path)
                    print(f"DEBUG: Removed local file {path}")
            try:
                #supabase.storage.from_("photos").remove(supabase_paths)
                supabase.storage.from_("photos").remove(original_supabase_paths)
                print(f"DEBUG: Removed {supabase_paths} from Supabase Storage")
                print(f"DEBUG: Removed {original_supabase_paths} from Supabase Storage")
            except Exception as e:
                print(f"Cleanup Error: {str(e)}")
        
        
    @staticmethod
    async def distribute_video(post_id: str, user_id: str, file_path: str, caption: str, description: str, platforms: list):
        original_path = file_path # assume it looks like /videos/video.mp4
        supabase_path = os.path.basename(file_path)
        try:
            """
            Coordinates multi-platform uploads.
            """
            tasks = []
            user_perms = await SubscriptionService.get_user_permissions(user_id, supabase)
            requested_platforms = len(platforms)
            print(f"DEBUG: User perms for watermark: {user_perms.get('no_watermark')}")

            if not user_perms.get("no_watermark", False):
                watermarked_path = file_path.replace(".mp4", "_watermarked.mp4")
                file_path = VideoProcessor.add_unipost_watermark(file_path, watermarked_path)
                supabase_path = (os.path.basename(file_path)).replace("_watermarked.mp4", ".mp4")
                print(f"DEBUG: Watermarking complete. New path: {file_path}")
            else:
                print(f"DEBUG: Watermarking skipped. Path: {file_path}")
            if requested_platforms > user_perms["max_platforms"]:
                return {"error": f"Upgrade to reach more than {user_perms['max_platforms']} platforms."}
            youtube_caption = caption
            if not user_perms["non_branded_caption"]:
                caption += "\nPosted via UniCore on iOS #unicore #poweredbyunicore"
                description += "\nPosted via UniCore on iOS #unicore #poweredbyunicore"

            if "youtube" in platforms:
                tasks.append(YouTubeService.upload_video(user_id, file_path, youtube_caption, description))
                
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
                    "platform_links": links_to_save,
                    "status": "published" # added
                }).eq("id", post_id).execute()


            return results
        finally:
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"DEBUG: Removed local file {file_path}")
            if os.path.exists(original_path):
                os.remove(original_path)
                print(f"DEBUG: Removed local file {original_path}")

            try:
                supabase.storage.from_("videos").remove([supabase_path])
                print(f"DEBUG: Removed {supabase_path} from Supabase Storage")
            except Exception as e:
                print(f"Cleanup Error: {str(e)}")