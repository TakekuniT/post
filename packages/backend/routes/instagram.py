from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def test_instagram():
    return {"message": "Instagram route is working"}