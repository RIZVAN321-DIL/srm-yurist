from pydantic import BaseModel, Field

class PaymentCreate(BaseModel):
    case_id: int
    amount: int = Field(gt=0)
    description: str | None = None
    status: str = "pending"

class PaymentUpdate(BaseModel):
    amount: int | None = None
    description: str | None = None
    status: str | None = None
