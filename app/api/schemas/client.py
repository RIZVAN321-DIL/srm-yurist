from pydantic import BaseModel, Field

class ClientCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    phone: str | None = Field(default=None, pattern=r'^\+?[\d\s\-\(\)]{5,20}$')
    email: str | None = Field(default=None, pattern=r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
    status: str = "active"
    tags: str | None = None
    notes: str | None = None

class ClientUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    status: str | None = None
    tags: str | None = None
    notes: str | None = None
