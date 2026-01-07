# xPost

## Instagram Account Setup

Must be a business account an must be linked to a Facebook Page.

Must be a business account an must be linked to a Facebook Page. Facebook Page can be created through a Facebook account and xPost will require a Facebook login.

How to link a Facebook Page to an Instagram account:
On the Instagram app (mobile):
Profile → ☰ → Settings
For professionals
Business tools and controls
Connect a Facebook Page
Select the exact Page

When logging in to your facebook account, you must select the right Facebook Page and you must allow xPost to access the instagram account you want to post on.

## Running the backend

cd packages/backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

## Running instagram api

You must first run ngrok to expose the backend to the internet.

ngrok config add-authtoken <YOUR_AUTHTOKEN>
ngrok http 8000

You must first run localtunnel to expose the backend to the internet.

npm install -g localtunnel
lt --port 8000 --subdomain taki-dev-xpost --host http://loca.lt

Go to https://ipv4.icanhazip.com to find your public IP address.

Paste the public IP address to the lt url.

# Updating create-checkout.ts

Must run this command every time code is updated:

supabase functions deploy create-checkout --no-verify-jwt --use-api

# Updating scheduler.py

After updating scheduler.py, run this command again:

python -m services.scheduler
