from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request

# This function identifies users by their verified ID or their IP
def get_user_or_ip(request: Request):
    # This matches the request.state.user_id we set in get_current_user
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return user_id
    return get_remote_address(request)

# Create the limiter instance here
limiter = Limiter(key_func=get_user_or_ip)