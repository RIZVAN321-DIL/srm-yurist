from pydantic import BaseModel, Field

class StageCreate(BaseModel):
    case_id: int
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    assigned_to: int | None = None
    order: int = 0

class StageUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    assigned_to: int | None = None
    status: str | None = None
    is_completed: bool | None = None
    order: int | None = None
