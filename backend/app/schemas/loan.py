from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class LoanCreate(BaseModel):
    borrower_name: str = Field(min_length=1, max_length=255)
    loaned_on: date
    due_on: date | None = None
    notes: str | None = None


class LoanReturn(BaseModel):
    returned_on: date


class LoanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    item_id: int
    borrower_name: str
    loaned_on: date
    due_on: date | None = None
    returned_on: date | None = None
    notes: str | None = None
