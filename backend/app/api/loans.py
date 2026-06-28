from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Item, Loan, User
from app.schemas.loan import LoanCreate, LoanOut, LoanReturn

router = APIRouter(tags=["loans"])


def _owned_item(db: Session, user: User, item_id: int) -> Item:
    item = db.scalar(select(Item).where(Item.id == item_id, Item.user_id == user.id))
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found")
    return item


@router.post("/items/{item_id}/loans", response_model=LoanOut, status_code=status.HTTP_201_CREATED)
def lend_item(
    item_id: int,
    payload: LoanCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Loan:
    item = _owned_item(db, user, item_id)
    open_loan = db.scalar(
        select(Loan).where(Loan.item_id == item.id, Loan.returned_on.is_(None))
    )
    if open_loan is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Item is already on loan")
    loan = Loan(item_id=item.id, **payload.model_dump())
    db.add(loan)
    db.commit()
    db.refresh(loan)
    return loan


@router.post("/loans/{loan_id}/return", response_model=LoanOut)
def return_loan(
    loan_id: int,
    payload: LoanReturn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Loan:
    loan = db.scalar(
        select(Loan).join(Item).where(Loan.id == loan_id, Item.user_id == user.id)
    )
    if loan is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Loan not found")
    loan.returned_on = payload.returned_on
    db.commit()
    db.refresh(loan)
    return loan
