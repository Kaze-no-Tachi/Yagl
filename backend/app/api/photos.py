from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Item, Photo, User
from app.schemas.item import PhotoOut
from app.services.storage import get_storage

router = APIRouter(prefix="/items/{item_id}/photos", tags=["photos"])

_ALLOWED = {"image/jpeg", "image/png", "image/webp", "image/heic"}
_MAX_BYTES = 15 * 1024 * 1024  # 15 MB


def _owned_item(db: Session, user: User, item_id: int) -> Item:
    item = db.scalar(select(Item).where(Item.id == item_id, Item.user_id == user.id))
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found")
    return item


@router.post("", response_model=PhotoOut, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    item_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Photo:
    item = _owned_item(db, user, item_id)
    if file.content_type not in _ALLOWED:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Unsupported image type")
    data = await file.read()
    if len(data) > _MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Image too large")

    path = get_storage().save(data, file.filename or "photo.jpg")
    is_primary = len(item.photos) == 0  # first photo becomes primary
    photo = Photo(item_id=item.id, path=path, is_primary=is_primary)
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return photo


@router.delete("/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_photo(
    item_id: int,
    photo_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    _owned_item(db, user, item_id)
    photo = db.scalar(select(Photo).where(Photo.id == photo_id, Photo.item_id == item_id))
    if photo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")
    get_storage().delete(photo.path)
    db.delete(photo)
    db.commit()
