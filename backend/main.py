from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes import default, chatbot

app = FastAPI()

# Allow CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change this to your Flutter web origin in prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(default.router)
app.include_router(chatbot.router)
