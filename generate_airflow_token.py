import jwt
import datetime

SECRET = 'redhat2025$'  # Must match AIRFLOW__API__ACCESS_TOKEN_SECRET
USERNAME = 'airflow'    # Must exist in Airflow
EXPIRATION_MINUTES = 60

payload = {
    'sub': USERNAME,
    'iat': datetime.datetime.utcnow(),
    'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=EXPIRATION_MINUTES)
}

token = jwt.encode(payload, SECRET, algorithm='HS256')

print("Token:")
print(token)
