import time
import datetime
from utils.db_client import supabase # Uses your existing DB client
from services.social_manager import SocialManager # Assuming this coordinates the uploads
from services.post_manager import PostManager
import asyncio
from routes.publish import get_local_video, get_local_photo
import os

async def check_and_publish_photos():
    # Get current time in ISO8601 format for Supabase comparison
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    print(f"[{now}] Checking for scheduled photo posts...")

    # 1. Query Supabase for posts that are 'pending' and ready to go
    # We use .lte (Less Than or Equal to) to find posts whose time has arrived
    response = supabase.table("posts") \
        .select("*") \
        .eq("status", "pending") \
        .lte("scheduled_at", now) \
        .execute()

    posts_to_publish = response.data

    if not posts_to_publish:
        return

    for post in posts_to_publish:
        if not post.get("photo_paths"):
            continue  # Skip if no photo_paths
        post_id = post['id']
        platforms = post['platforms'] 
        
        print(f"Publishing Photo Post {post_id} to {platforms}...")

        try:
            # 2. Update status to 'processing' so no other worker picks it up
            supabase.table("posts").update({"status": "processing"}).eq("id", post_id).execute()

            # 3. Trigger your social services
            print(f"Downloading photos: {post['photo_paths']}...")
            local_paths = []
            for path in post['photo_paths']:
                local_path = await get_local_photo(path)
                local_paths.append(local_path)
            
            if local_paths:
                print(f"Photo download complete.")
                results = await PostManager.distribute_photos(post_id=post_id, user_id=post['user_id'], file_paths=local_paths, caption=post['caption'], platforms=post['platforms'])
                # Check if any results contains an Exception/Error
                errors = [r for r in results if isinstance(r, Exception)]
                
                if errors:
                    print(f"Post {post_id} failed on some platforms: {errors}")
                    supabase.table("posts").update({"status": "failed"}).eq("id", post_id).execute()
                else:
                    supabase.table("posts").update({"status": "published"}).eq("id", post_id).execute()
                    print(f"Post {post_id} successfully published.")
            else:
                raise FileNotFoundError(f"Could not find downloaded file at {local_path}")
            
           

        except Exception as e:
            print(f"Failed to publish post {post_id}: {str(e)}")
            # Mark as failed to debug it later
            supabase.table("posts").update({"status": "failed"}).eq("id", post_id).execute()





async def check_and_publish():
    # Get current time in ISO8601 format for Supabase comparison
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    print(f"[{now}] Checking for scheduled posts...")

    # 1. Query Supabase for posts that are 'pending' and ready to go
    # We use .lte (Less Than or Equal to) to find posts whose time has arrived
    response = supabase.table("posts") \
        .select("*") \
        .eq("status", "pending") \
        .lte("scheduled_at", now) \
        .execute()

    posts_to_publish = response.data

    if not posts_to_publish:
        return

    for post in posts_to_publish:
        if not post.get("video_path"):
            continue  # Skip if no video_path
        post_id = post['id']
        platforms = post['platforms'] 
        
        print(f"Publishing Post {post_id} to {platforms}...")

        try:
            # 2. Update status to 'processing' so no other worker picks it up
            supabase.table("posts").update({"status": "processing"}).eq("id", post_id).execute()

            # 3. Trigger your social services
            print(f"Downloading video: {post['video_path']}...")
            local_path = await get_local_video(post['video_path'])
            
            if os.path.exists(local_path):
                print(f"Video downloaded to {local_path}")
                results = await PostManager.distribute_video(
                    post_id=post_id,
                    user_id=post['user_id'],
                    file_path=local_path,
                    caption=post['caption'],
                    description=post['description'],
                    platforms=post['platforms']
                )
                # Check if any results contains an Exception/Error
                errors = [r for r in results if isinstance(r, Exception)]
                
                if errors:
                    print(f"Post {post_id} failed on some platforms: {errors}")
                    supabase.table("posts").update({"status": "failed"}).eq("id", post_id).execute()
                else:
                    supabase.table("posts").update({"status": "published"}).eq("id", post_id).execute()
                    print(f"Post {post_id} successfully published.")
            else:
                raise FileNotFoundError(f"Could not find downloaded file at {local_path}")
            
           

        except Exception as e:
            print(f"Failed to publish post {post_id}: {str(e)}")
            # Mark as failed to debug it later
            supabase.table("posts").update({"status": "failed"}).eq("id", post_id).execute()

def run_scheduler():
    # Start the heartbeat
    while True:
        print("UniPost Scheduler started...")
        try:
            asyncio.run(check_and_publish())
            asyncio.run(check_and_publish_photos())
        except Exception as e:
            print(f"Worker Error: {e}")
        
        # Wait 60 seconds before checking again
        time.sleep(60)

run_scheduler()