from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.models import User
from app.schemas.scan import ScanRequest, ScanResponse
from app.services import barcode

router = APIRouter(tags=["scan"])


@router.post("/scan", response_model=ScanResponse)
def scan_barcode(payload: ScanRequest, _: User = Depends(get_current_user)) -> ScanResponse:
    """Resolve a scanned barcode into ranked game candidates for the user to confirm.

    Always returns 200 with a (possibly empty) candidate list — an empty list is
    the client's cue to offer manual search/entry.
    """
    candidates = barcode.resolve_barcode(payload.barcode)
    return ScanResponse(barcode=payload.barcode, candidates=candidates)
