import os
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles





load_dotenv()

from fastapi import FastAPI, APIRouter, Request
from routes import instagram, youtube, tiktok, facebook, publish, linkedin

app = FastAPI()

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
app.include_router(publish.router, prefix="/publish")



@app.get("/")
def read_root():
    return {"message": "xPost FastAPI backend running"}