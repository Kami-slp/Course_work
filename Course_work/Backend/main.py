import os
import re
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Annotated
from uuid import UUID, uuid4

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
import bcrypt
from pydantic import BaseModel, EmailStr, Field
from remnawave import RemnawaveSDK
from remnawave.models import CreateUserRequestDto
from sqlalchemy.orm import Session

from database import User, get_db, init_db

load_dotenv()

REMNAWAVE_BASE_URL = os.getenv("REMNAWAVE_BASE_URL")
REMNAWAVE_TOKEN = os.getenv("REMNAWAVE_TOKEN")
JWT_SECRET = os.getenv("JWT_SECRET", "change-me")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_DAYS = 30
DEFAULT_SQUAD = UUID(os.getenv("DEFAULT_SQUAD_UUID", "c5423178-7b12-4b89-92e8-195848a7e5fb"))
DEFAULT_DAYS = int(os.getenv("DEFAULT_DAYS", "30"))

security = HTTPBearer()
remnawave: RemnawaveSDK | None = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global remnawave
    if not REMNAWAVE_BASE_URL or not REMNAWAVE_TOKEN:
        raise RuntimeError("REMNAWAVE_BASE_URL и REMNAWAVE_TOKEN обязательны в .env")
    init_db()
    remnawave = RemnawaveSDK(base_url=REMNAWAVE_BASE_URL, token=REMNAWAVE_TOKEN)
    yield

app = FastAPI(title="VPN Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class RegisterRequest(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(min_length=6, max_length=128)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserResponse(BaseModel):
    email: str
    username: str
    remnawave_username: str

class SubscriptionResponse(BaseModel):
    subscription_url: str | None = None

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode(), password_hash.encode())

def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(days=JWT_EXPIRE_DAYS)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload.get("sub", ""))
    except (JWTError, ValueError):
        raise HTTPException(status_code=401, detail="Недействительный токен")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="Пользователь не найден")
    return user

def is_duplicate_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return any(x in msg for x in ("exist", "already", "duplicate", "409", "conflict"))

def make_remnawave_username(username: str) -> str:
    safe = re.sub(r"[^a-zA-Z0-9_]", "_", username.lower())[:20]
    return f"{safe}_{uuid4().hex[:6]}"

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/register", response_model=TokenResponse)
async def register(body: RegisterRequest, db: Annotated[Session, Depends(get_db)]):
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(status_code=409, detail="Email уже зарегистрирован")
    if db.query(User).filter(User.username == body.username).first():
        raise HTTPException(status_code=409, detail="Username уже занят")

    rw_username = make_remnawave_username(body.username)
    expire_at = datetime.utcnow() + timedelta(days=DEFAULT_DAYS)

    assert remnawave is not None
    try:
        rw_user = await remnawave.users.create_user(
            CreateUserRequestDto(
                username=rw_username,
                expire_at=expire_at,
                active_internal_squads=[DEFAULT_SQUAD],
            )
        )
    except Exception as e:
        if is_duplicate_error(e):
            raise HTTPException(status_code=409, detail="Username уже занят в панели")
        raise HTTPException(status_code=400, detail=str(e))

    user = User(
        email=body.email,
        username=body.username,
        password_hash=hash_password(body.password),
        remnawave_username=rw_username,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return TokenResponse(access_token=create_access_token(user.id))

@app.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: Annotated[Session, Depends(get_db)]):
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный email или пароль")
    return TokenResponse(access_token=create_access_token(user.id))

@app.get("/me", response_model=UserResponse)
async def me(user: Annotated[User, Depends(get_current_user)]):
    return UserResponse(
        email=user.email,
        username=user.username,
        remnawave_username=user.remnawave_username,
    )

@app.get("/me/subscription", response_model=SubscriptionResponse)
async def my_subscription(user: Annotated[User, Depends(get_current_user)]):
    assert remnawave is not None
    try:
        rw_user = await remnawave.users.get_user_by_username(user.remnawave_username)
        sub_url = getattr(rw_user, "subscription_url", None) or getattr(rw_user, "sub_url", None)
        if sub_url is None and hasattr(rw_user, "model_dump"):
            data = rw_user.model_dump()
            sub_url = data.get("subscriptionUrl") or data.get("subscription_url")
        return SubscriptionResponse(subscription_url=sub_url)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Не удалось получить subscription: {e}")