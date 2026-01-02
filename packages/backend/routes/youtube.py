from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def test_youtube():
    return {"message": "Youtube route is working"}