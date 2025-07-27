from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes import default, chatbot, geminiADK
# from routes.geminiADK.smart_actions import router as smart_actions_router


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
app.include_router(geminiADK.router)
