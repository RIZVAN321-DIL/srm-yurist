from pydantic import BaseModel, Field

class CaseCreate(BaseModel):
    client_id: int
    title: str = Field(min_length=1, max_length=500)
    case_type: str | None = None
    description: str | None = None
    status: str = "new"
    template_id: int | None = None
    parent_case_id: int | None = None
    statute_deadline: str | None = None

class CaseUpdate(BaseModel):
    title: str | None = None
    case_type: str | None = None
    description: str | None = None
    status: str | None = None
    owner_id: int | None = None
    statute_deadline: str | None = None

class CaseTransfer(BaseModel):
    new_owner_id: int
