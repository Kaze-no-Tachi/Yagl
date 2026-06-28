from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Item, User
from app.schemas.item import ItemCreate, ItemList, ItemOut, ItemUpdate

router = APIRouter(prefix="/items", tags=["items"])


def _owned_item(db: Session, user: User, item_id: int) -> Item:
    item = db.scalar(
        select(Item)
        .where(Item.id == item_id, Item.user_id == user.id)
        .options(selectinload(Item.photos), selectinload(Item.loans), selectinload(Item.platform))
    )
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found")
    return item


@router.get("", response_model=ItemList)
def list_items(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    q: str | None = Query(None, description="Search in title"),
    kind: str | None = None,
    format: str | None = None,
    condition: str | None = None,
    platform_id: int | None = None,
    source: str | None = None,
    on_loan: bool | None = Query(None, description="Filter items currently lent out"),
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> ItemList:
    filters = [Item.user_id == user.id]
    if q:
        filters.append(Item.title.ilike(f"%{q}%"))
    if kind:
        filters.append(Item.kind == kind)
    if format:
        filters.append(Item.format == format)
    if condition:
        filters.append(Item.condition == condition)
    if platform_id is not None:
        filters.append(Item.platform_id == platform_id)
    if source:
        filters.append(Item.source == source)

    total = db.scalar(select(func.count()).select_from(Item).where(*filters)) or 0
    stmt = (
        select(Item)
        .where(*filters)
        .options(selectinload(Item.photos), selectinload(Item.loans), selectinload(Item.platform))
        .order_by(Item.title)
        .limit(limit)
        .offset(offset)
    )
    items = list(db.scalars(stmt).all())
    if on_loan is not None:
        items = [it for it in items if _is_on_loan(it) == on_loan]
    return ItemList(items=[ItemOut.model_validate(it) for it in items], total=total)


def _is_on_loan(item: Item) -> bool:
    return any(loan.returned_on is None for loan in item.loans)


@router.post("", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: ItemCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ItemOut:
    item = Item(user_id=user.id, **payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return ItemOut.model_validate(_owned_item(db, user, item.id))


@router.get("/{item_id}", response_model=ItemOut)
def get_item(
    item_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ItemOut:
    return ItemOut.model_validate(_owned_item(db, user, item_id))


@router.patch("/{item_id}", response_model=ItemOut)
def update_item(
    item_id: int,
    payload: ItemUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ItemOut:
    item = _owned_item(db, user, item_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    return ItemOut.model_validate(_owned_item(db, user, item_id))


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(
    item_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    item = _owned_item(db, user, item_id)
    db.delete(item)
    db.commit()
