import asyncio
import os
from services.tiktok import TikTokService
from services.youtube import YouTubeService
from services.instagram import InstagramService
from services.facebook import FacebookService

# Replace this with a real User ID from your Supabase 'profiles' table
TEST_USER_ID = "ff95c9b9-c4ae-408c-a290-b04878d0d66a"

# Path to a real 10-15 second mp4 file on your Mac for testing
TEST_VIDEO_PATH = "/Users/ttanemori/myFiles/XPost/short_test.mp4"

async def test_tiktok():
    print("\n--- Testing TikTok Service ---")
    result = await TikTokService.upload_video(
        user_id=TEST_USER_ID,
        file_path=TEST_VIDEO_PATH,
        caption="Testing TikTok Service Layer #api #coding"
    )
    print(f"TikTok Result: {result}")

async def test_youtube():
    print("\n--- Testing YouTube Service ---")
    result = await YouTubeService.upload_video(
        user_id=TEST_USER_ID,
        file_path=TEST_VIDEO_PATH,
        title="Service Layer Test",
        description="Testing the YouTube service orchestration."
    )
    print(f"YouTube Result: {result}")

async def test_instagram():
    print("\n--- Testing Instagram Service ---")
    result = await InstagramService.upload_video(
        user_id=TEST_USER_ID,
        file_path=TEST_VIDEO_PATH,
        caption="Testing Instagram Service Layer #api #coding"
    )
    print(f"Instagram Result: {result}")

async def test_facebook():
    print("\n--- Testing Facebook Service ---")
    result = await FacebookService.upload_video(
        user_id=TEST_USER_ID,
        file_path=TEST_VIDEO_PATH,
        caption="Testing Facebook Service Layer #api #coding"
    )
    print(f"Facebook Result: {result}")

async def run_tests():
    # await test_tiktok()
    # await test_youtube()
    # await test_instagram()
    await test_facebook()

if __name__ == "__main__":
    asyncio.run(run_tests())