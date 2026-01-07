from typing import Dict, Any

class SubscriptionService:
    # Source of truth for Tier capabilities
    TIER_CONFIG = {
        "free": {
            "max_platforms": 3,
            "unlimited_posts": False,
            "no_watermark": False,
            "non_branded_caption": False
        },
        "pro": {
            "max_platforms": 5,
            "unlimited_posts": True,
            "no_watermark": True,
            "non_branded_caption": False
        },
        "elite": {
            "max_platforms": 20, # "Unlimited" logic
            "unlimited_posts": True,
            "no_watermark": True,
            "non_branded_caption": True
        }
    }

    @staticmethod
    async def get_user_permissions(user_id: str, supabase_client) -> Dict[str, Any]:
        """
        Fetches the user's tier from the subscriptions table 
        and returns their specific feature flags.
        """
        # Query your 'subscriptions' table as requested
        response = supabase_client.table("subscriptions") \
            .select("tier") \
            .eq("user_id", user_id) \
            .maybe_single() \
            .execute()

        # Fallback to 'free' if no subscription record exists
        user_tier = "free"
        if response.data and response.data.get("tier"):
            user_tier = response.data["tier"].lower()
            print(f"User tier found from DB: {user_tier}")
        else:
            print(f"No user tier found in DB. Defaulting to free.")

        # Return the config for that tier, defaulting to free if tier name is unknown
        return SubscriptionService.TIER_CONFIG.get(user_tier, SubscriptionService.TIER_CONFIG["free"])