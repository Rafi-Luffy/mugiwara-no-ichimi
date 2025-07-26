from typing import Dict, Optional, List, Union, Dict
from pydantic import BaseModel, EmailStr

class PreferenceValue(BaseModel):
    enabled: bool
    value: Optional[Union[str, int, float, List[str]]] = None

class PreferencesPayload(BaseModel):
    user_id: str
    user_name: str
    user_email: EmailStr
    preferences: Dict[str, Union[bool, PreferenceValue]]

class UserPreferencesResponse(BaseModel):
    success: bool
    message: str
    preferences_id: Optional[str] = None
    saved_at: Optional[str] = None