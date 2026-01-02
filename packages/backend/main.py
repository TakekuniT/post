from fastapi import FastAPI
from routes import instagram, youtube

app = FastAPI()

app.include_router(instagram.router, prefix="/instagram")
app.include_router(youtube.router, prefix="/youtube")


@app.get("/")
def read_root():
    return {"message": "xPost FastAPI backend running"}