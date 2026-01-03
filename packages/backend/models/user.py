from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class SocialAccount(BaseModel):
    """
    This defines the 'Shape' of a row in your social_accounts table.
    It helps Python catch errors if a field is missing.
    """
    user_id: str
    platform: str  # 'youtube', 'tiktok', 'instagram'
    access_token: str
    refresh_token: Optional[str] = None
    expires_at: datetime
    instagram_business_id: Optional[str] = None

    class Config:
        from_attributes = True # Allows Pydantic to read data from Supabase/SQL

