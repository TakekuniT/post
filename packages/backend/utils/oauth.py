import os
import requests
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import base64
import secrets

class OAuthManager:
    def __init__(self):
        # YouTube Credentials
        self.yt_client_id = os.getenv("YOUTUBE_CLIENT_ID")
        self.yt_client_secret = os.getenv("YOUTUBE_CLIENT_SECRET")
        self.yt_redirect_uri = os.getenv("YOUTUBE_REDIRECT_URI")

        # Instagram Credentials
        self.ig_client_id = os.getenv("INSTAGRAM_CLIENT_ID")
        self.ig_client_secret = os.getenv("INSTAGRAM_CLIENT_SECRET")
        self.ig_redirect_uri = os.getenv("INSTAGRAM_REDIRECT_URI")

        # TikTok Credentials
        self.tiktok_client_id = os.getenv("TIKTOK_CLIENT_ID")
        self.tiktok_client_secret = os.getenv("TIKTOK_CLIENT_SECRET")
        self.tiktok_redirect_uri = os.getenv("TIKTOK_REDIRECT_URI")


    # --- TIKTOK / TIKTOK LOGIC ---
    def generate_pkce_pair(self):
        """Generates a code_verifier and code_challenge for PKCE."""
        # 1. Create a high-entropy random string (verifier)
        verifier = secrets.token_urlsafe(64)
        
        # 2. Hash it with SHA-256
        sha256_hash = hashlib.sha256(verifier.encode('utf-8')).digest()
        
        # 3. Base64url encode the hash (challenge)
        challenge = base64.urlsafe_b64encode(sha256_hash).decode('utf-8').replace('=', '')
        
        return verifier, challenge
    
    def exchange_tiktok_code(self, code: str, verifier: str):
        """Exchanges the auth code and verifier for actual tokens."""
        url = "https://open.tiktokapis.com/v2/oauth/token/"
        
        # TikTok requires this specific content type
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        
        data = {
            "client_key": self.tiktok_client_id,
            "client_secret": self.tiktok_client_secret, 
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": os.getenv("TIKTOK_REDIRECT_URI"),
            "code_verifier": verifier  # This is why we needed the state/cookie!
        }
        
        response = requests.post(url, data=data, headers=headers)
        return response.json()
    
    def refresh_tiktok_token(self, refresh_token: str):
        url = "https://open.tiktokapis.com/v2/oauth/token/"
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        
        data = {
            "client_key": os.getenv("TIKTOK_CLIENT_ID"),
            "client_secret": os.getenv("TIKTOK_CLIENT_SECRET"),
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }
        
        response = requests.post(url, data=data, headers=headers)
        return response.json()
    

    # --- YOUTUBE / GOOGLE LOGIC ---

    def refresh_youtube_token(self, refresh_token: str) -> dict:
        """Exchanges a refresh token for a brand new access token."""
        url = "https://oauth2.googleapis.com/token"
        data = {
            "client_id": self.yt_client_id,
            "client_secret": self.yt_client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }
        response = requests.post(url, data=data)
        res_json = response.json()
        
        # Calculate new expiry (usually 3600 seconds)
        expires_in = res_json.get("expires_in", 3600)
        res_json["expires_at"] = datetime.utcnow() + timedelta(seconds=expires_in)
        return res_json

    # --- INSTAGRAM / META LOGIC ---

    def get_ig_long_lived_token(self, short_lived_token: str) -> dict:
        """Swaps a 1-hour IG token for a 60-day token."""
        url = "https://graph.facebook.com/v21.0/oauth/access_token"
        params = {
            "grant_type": "fb_exchange_token",
            "client_id": self.ig_client_id,
            "client_secret": self.ig_client_secret,
            "fb_exchange_token": short_lived_token
        }
        response = requests.get(url, params=params)
        res_json = response.json()
        
        # IG long-lived tokens usually last 60 days (5184000 seconds)
        expires_in = res_json.get("expires_in", 5184000)
        res_json["expires_at"] = datetime.utcnow() + timedelta(seconds=expires_in)
        return res_json

    def refresh_ig_long_lived_token(self, long_lived_token: str) -> dict:
        """Refreshes an existing 60-day token (must be at least 24h old)."""
        url = "https://graph.facebook.com/v21.0/refresh_access_token"
        params = {
            "grant_type": "ig_refresh_token",
            "access_token": long_lived_token
        }
        response = requests.get(url, params=params)
        return response.json()