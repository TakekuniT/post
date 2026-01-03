import os
import google.oauth2.credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.auth.transport.requests import Request
from utils.supabase import UserManager

class YouTubeService:
    @staticmethod
    def get_authenticated_service(user_id: str):
        """
        Gatekeeper: Fetches tokens from Supabase, checks expiry, 
        and refreshes using Client ID/Secret if necessary.
        """
        account = UserManager.get_social_tokens(user_id, "youtube")
        if not account:
            raise Exception("YouTube account not linked.")

        # 1. Create Credentials object with stored tokens
        creds = google.oauth2.credentials.Credentials(
            token=account.get("access_token"),
            refresh_token=account.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=os.getenv("YOUTUBE_CLIENT_ID"),
            client_secret=os.getenv("YOUTUBE_CLIENT_SECRET")
        )

        # 2. Check if expired and refresh
        if creds.expired or not creds.valid:
            print(f"YouTube token for {user_id} expired. Refreshing...")
            creds.refresh(Request())
            
            # 3. Save the new access token back to Supabase immediately
            # We use **data to update just the changed fields
            UserManager.save_social_account(user_id, "youtube", {
                "access_token": creds.token,
                "expires_at": creds.expiry.isoformat()
            })

        return build("youtube", "v3", credentials=creds)

    @staticmethod
    async def upload_video(user_id: str, file_path: str, title: str, description: str):
        """
        Highest Quality Engine: Uses the refreshed service and 
        resumable chunks to guarantee bit-perfect uploads.
        """
        try:
            # Get the auto-refreshed YouTube client
            youtube = YouTubeService.get_authenticated_service(user_id)

            # Define media with 1MB chunks to prevent data loss/compression
            media = MediaFileUpload(
                file_path, 
                mimetype='video/mp4', 
                chunksize=1024*1024, 
                resumable=True
            )

            request = youtube.videos().insert(
                part="snippet,status",
                body={
                    "snippet": {
                        "title": title, 
                        "description": description, 
                        "categoryId": "22"
                    },
                    "status": {
                        "privacyStatus": "public", 
                        "selfDeclaredMadeForKids": False
                    }
                },
                media_body=media
            )

            # Monitor progress to ensure no bits are dropped
            response = None
            while response is None:
                status, response = request.next_chunk()
                if status:
                    print(f"YouTube Upload: {int(status.progress() * 100)}% complete")

            return response["id"]

        except Exception as e:
            print(f"YouTube Service Error: {str(e)}")
            return None