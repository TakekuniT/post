import os
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles

from utils.db_client import UserManager

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from utils.limiter import limiter
load_dotenv()

from fastapi import FastAPI, APIRouter, Request, HTTPException
from routes import instagram, youtube, tiktok, facebook, publish, linkedin, threads

app = FastAPI()


app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# @app.middleware("http")
# async def add_ngrok_skip_header(request: Request, call_next):
#     response = await call_next(request)
#     response.headers["ngrok-skip-browser-warning"] = "any-value"
#     response.headers["x-ngrok-skip-browser-warning"] = "any-value"
#     return response

@app.middleware("http")
async def add_localtunnel_skip_header(request: Request, call_next):
    response = await call_next(request)
    # This header bypasses the Localtunnel "Reminder" page for everyone
    response.headers["bypass-tunnel-reminder"] = "true"
    return response

# Set up static files
if not os.path.exists("static"):
    os.mkdir("static")
app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(instagram.router, prefix="/instagram")
app.include_router(youtube.router, prefix="/youtube")
app.include_router(tiktok.router, prefix="/tiktok")
app.include_router(facebook.router, prefix="/facebook")
app.include_router(linkedin.router, prefix="/linkedin")
app.include_router(threads.router, prefix="/threads")
app.include_router(publish.router, prefix="/publish")



@app.get("/")
def read_root():
    return {"message": "xPost FastAPI backend running"}

@app.delete("/disconnect/{platform}")
@limiter.limit("10/minute")
async def disconnect(request: Request,platform: str, user_id: str):
    try:
        success = UserManager.delete_social_account(user_id, platform)
        if success:
            return {"status": "success", "message": f"Successfully disconnected {platform}"}
        else:
            raise HTTPException(status_code=404, detail="No account found for this user.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/accounts/{user_id}")
@limiter.limit("10/minute")
async def get_connected_accounts(request: Request,user_id: str):
    accounts = UserManager.get_all_user_accounts(user_id)
    return [acc["platform"] for acc in accounts]