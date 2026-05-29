from pydantic import BaseModel, Field

class UserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    login: str = Field(min_length=3, max_length=100)
    password: str = Field(min_length=6, max_length=255)
    role: str = "lawyer"

class UserLogin(BaseModel):
    login: str
    password: str

class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6, max_length=255)
