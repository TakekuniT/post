import os
import requests
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import base64
import secrets
from fastapi import Request
import json
from jose import jwt, jwk # from python-jose
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from dotenv import load_dotenv

load_dotenv()

security = HTTPBearer()

# Replace with your Supabase JWT Secret (Found in Supabase Settings -> API)
raw_jwk_string = json.loads(os.getenv("SUPABASE_JWK_SECRET"))

if not raw_jwk_string:
    raise ValueError("JWT Secret not found in environment variables")

if isinstance(raw_jwk_string, str):
    # If it's a string, we need to decode it
    jwk_dict = json.loads(raw_jwk_string)
else:
    # It's already a dictionary, just use it
    jwk_dict = raw_jwk_string

if "keys" in jwk_dict and isinstance(jwk_dict["keys"], list):
    actual_key = jwk_dict["keys"][0]
else:
    actual_key = jwk_dict

try:
    public_key = jwk.construct(actual_key, algorithm="ES256")
    print("JWK Public Key constructed successfully!")
except Exception as e:
    print(f"Failed to construct JWK: {e}")
    raise


async def get_current_user(request: Request, cred: HTTPAuthorizationCredentials = Security(security)):
    token = cred.credentials
    print(f"DEBUG: received credentials: {cred}")
    try:
        # Verify the token using your secret
        payload = jwt.decode(
            token, 
            public_key, 
            algorithms=["ES256"], 
            audience="authenticated",
          
        )

        
        
        # Ensure the user_id from the token is returned
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="user id missing, invalid token payload")
        request.state.user_id = user_id
        return user_id
        
    except Exception as e:
        print(f"JWT Error: {e}")
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {str(e)}")


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

        # Facebook Credentials
        self.fb_client_id = os.getenv("FACEBOOK_CLIENT_ID")
        self.fb_client_secret = os.getenv("FACEBOOK_CLIENT_SECRET")
        self.fb_redirect_uri = os.getenv("FACEBOOK_REDIRECT_URI")


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
        """
        Uses the current refresh_token to get a NEW access_token 
        and a NEW refresh_token from TikTok.
        """
        url = "https://open.tiktokapis.com/v2/oauth/token/"
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        
        data = {
            "client_key": os.getenv("TIKTOK_CLIENT_ID"), # TikTok calls it Client Key
            "client_secret": os.getenv("TIKTOK_CLIENT_SECRET"),
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }
        
        try:
            response = requests.post(url, data=data, headers=headers)
            res_data = response.json()
            
            # TikTok returns error details inside the JSON even with a 200 status
            if "access_token" in res_data:
                return {
                    "success": True,
                    "access_token": res_data["access_token"],
                    "refresh_token": res_data["refresh_token"], # SAVE THIS! The old one is now invalid
                    "expires_at": (datetime.utcnow() + timedelta(seconds=res_data["expires_in"])).isoformat(),
                    "refresh_expires_at": (datetime.utcnow() + timedelta(seconds=res_data["refresh_expires_in"])).isoformat()
                }
            else:
                return {
                    "success": False, 
                    "error": res_data.get("error_description", "Failed to refresh TikTok token")
                }
                
        except Exception as e:
            return {"success": False, "error": str(e)}
        

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
    
    # --- FACEBOOK / META LOGIC ---
    def refresh_fb_long_lived_token(current_token: str):
        """
        Exchanges a valid long-lived token for a new long-lived token.
        Extends the expiration back to 60 days from today.
        """
        url = "https://graph.facebook.com/v19.0/oauth/access_token"
        
        params = {
            "grant_type": "fb_exchange_token",
            "client_id": self.fb_client_id,
            "client_secret": self.fb_client_secret,
            "fb_exchange_token": current_token
        }
        
        try:
            response = requests.get(url, params=params)
            data = response.json()
            
            if "access_token" in data:
                # Facebook long-lived tokens usually last 60 days
                expires_in_seconds = data.get("expires_in", 5184000) # Default to 60 days
                new_expiry = datetime.utcnow() + timedelta(seconds=expires_in_seconds)
                
                return {
                    "success": True,
                    "access_token": data["access_token"],
                    "expires_at": new_expiry.isoformat()
                }
            else:
                return {"success": False, "error": data.get("error", "Unknown error")}
                
        except Exception as e:
            return {"success": False, "error": str(e)}