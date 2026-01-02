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

ngrok http 8000

## Setting up instagram account
