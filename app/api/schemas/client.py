from pydantic import BaseModel, Field

class ClientCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    phone: str | None = None
    email: str | None = None
    status: str = "active"

class ClientUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    status: str | None = None
