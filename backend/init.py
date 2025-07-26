from firebase_admin import credentials, storage, firestore
import firebase_admin

# Firebase init
cred = credentials.Certificate("secrets/mugiwara-no-ichimi-firebase-adminsdk-fbsvc-6bf822a736.json")
firebase_admin.initialize_app(cred, {
    'storageBucket': 'mugiwara-no-ichimi.firebasestorage.app'
})
bucket = storage.bucket()
db = firestore.client()