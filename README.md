# CloudMentor — React + AWS Lambda + S3 + DynamoDB + OpenAI

CloudMentor is a classroom-ready AI learning assistant project for Web Development, DevOps, Cloud, and AI engineering students.

Students can:

- Paste study notes directly into the app
- Upload text-based files
- Store uploaded files in S3
- Generate summaries, interactive quizzes, flippable flashcards, and exact day-by-day study plans
- Save output and progress history in DynamoDB
- Run the app locally, on an EC2 machine, or as a real serverless AWS backend
- Deploy updates automatically with GitHub Actions

---

## 1. What students will learn

- React + Vite frontend development
- Modern dark/glass UI design
- API integration from React
- AWS Lambda backend design
- AWS SAM infrastructure-as-code
- API Gateway HTTP API
- S3 file upload using pre-signed URLs
- DynamoDB persistence
- OpenAI API integration from a backend
- EC2 hosting with Nginx
- GitHub Actions CI/CD
- CloudWatch/systemd logs and troubleshooting

---

## 2. Project architecture

### Local mode from your laptop

```text
Browser
  ↓
React frontend: http://localhost:5173
  ↓
SAM Local API: http://localhost:3000
  ↓
Lambda code running inside Docker
  ↓
OpenAI API
```

Local mode can use either:

```text
STORAGE_MODE=local  → uploads are saved in local temporary storage
STORAGE_MODE=s3     → uploads are saved in real AWS S3
```

### EC2 classroom mode

```text
Browser
  ↓
http://EC2_PUBLIC_IP
  ↓
Nginx serves React build files
  ↓
Nginx proxies /api/* to SAM Local API on 127.0.0.1:3000
  ↓
Lambda code runs through SAM Local on the EC2 machine
  ↓
OpenAI API + S3 + DynamoDB
```

In EC2 mode, the frontend uses:

```env
VITE_API_BASE_URL=http://EC2_PUBLIC_IP/api
```

The browser does not call `localhost`. It calls the EC2 public IP.

### Full AWS serverless mode

```text
React frontend
  ↓
API Gateway HTTP API
  ↓
AWS Lambda
  ↓
OpenAI API
  ↓
S3 + DynamoDB
```

This is the true production-style serverless deployment. AWS SAM packages and pushes the Lambda code to AWS.

---

## 3. Project structure

```text
cloudmentor-serverless/
├── .github/
│   └── workflows/
│       ├── deploy-ec2.yml
│       └── deploy-serverless-backend.yml
├── backend/
│   ├── template.yaml
│   ├── package.json
│   ├── env.local.example.json
│   ├── env.ec2.example.json
│   ├── env.production.example.json
│   ├── events/
│   │   ├── summarize.json
│   │   └── upload-url.json
│   └── src/
│       ├── app.mjs
│       └── prompts.mjs
├── frontend/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── .env.example
│   ├── .env.ec2.example
│   ├── public/
│   │   └── cloudmentor-reference.png
│   └── src/
│       ├── App.jsx
│       ├── api.js
│       ├── main.jsx
│       └── styles.css
├── scripts/
│   ├── create-ec2-aws-resources.sh
│   ├── ec2-bootstrap.sh
│   └── ec2-deploy.sh
├── docs/
│   └── teaching-plan.md
├── .gitignore
└── README.md
```

---

## 4. Main API endpoints

```text
GET  /health
GET  /history
POST /upload-url
PUT  /local-upload/{key}      # local storage mode only
POST /process-file
POST /summarize
POST /quiz
POST /flashcards
POST /study-plan
POST /save-progress
```

### Output behavior in the latest version

CloudMentor now returns structured data for the learning tools, not only plain Markdown.

```text
Quiz       → interactive MCQ cards with correct/wrong feedback and score
Flashcards → real flippable cards with hints, previous/next navigation
Study plan → exactly the number of days requested by the student, up to 30 days
Summary    → readable Markdown summary
```

In mock mode, the backend generates structured demo data without OpenAI. In OpenAI mode, the prompt asks the model to return strict JSON for quiz, flashcards, and study plan so the React UI can render interactive components.

---

## 5. Create an OpenAI API key

1. Go to the OpenAI API platform.
2. Create or select a project.
3. Create an API key.
4. Copy the key immediately and keep it safe.
5. Do not place the OpenAI API key in the React frontend `.env` file.

Use the key only in one of these places:

```text
backend/env.json              # local development only, do not commit
backend/env.ec2.json          # EC2 deployment only, do not commit
GitHub Actions secret         # CI/CD
SAM parameter OpenAiApiKey    # AWS Lambda deployment
```

Recommended model for this classroom version:

```text
gpt-4.1-mini
```

You can replace it with another text-capable OpenAI model if required.

---

## 6. Prerequisites for local development

Install these on your laptop:

1. Node.js 20 or newer
2. npm
3. Docker Desktop
4. AWS CLI v2
5. AWS SAM CLI
6. Git
7. OpenAI API key
8. AWS account, only required if you want S3/DynamoDB or real Lambda deployment

Check versions:

```bash
node -v
npm -v
docker --version
aws --version
sam --version
git --version
```

Configure AWS CLI if you plan to use S3/DynamoDB from local:

```bash
aws configure
```

For classroom testing without S3, AWS CLI configuration is not required.

---

## 7. Run locally with local file storage

This is the easiest first run for students.

### Terminal 1 — backend

```bash
cd cloudmentor-serverless/backend
npm install
cp env.local.example.json env.json
```

Edit `env.json`. For local laptop mode, use this:

```json
{
  "CloudMentorFunction": {
    "AI_MODE": "mock",
    "OPENAI_API_KEY": "",
    "OPENAI_MODEL": "gpt-4.1-mini",
    "TABLE_NAME": "",
    "MATERIALS_BUCKET": "",
    "CORS_ORIGIN": "*",
    "STORAGE_MODE": "local",
    "LOCAL_DEV": "true"
  }
}
```

The backend folder also includes production-style examples:

```text
backend/env.local.example.json       # local laptop, mock AI, local file storage
backend/env.ec2.example.json         # EC2 mode, S3/DynamoDB, usually mock first
backend/env.production.example.json  # production-like values for OpenAI + S3 + DynamoDB
```

For real OpenAI mode, use:

```json
"AI_MODE": "openai",
"OPENAI_API_KEY": "sk-proj-your-real-key"
```


### Mock AI mode vs real OpenAI mode

For the first local classroom run, use mock mode so students do not need API credit:

```json
"AI_MODE": "mock",
"OPENAI_API_KEY": ""
```

In mock mode, CloudMentor returns realistic demo summaries, quizzes, flashcards, and study plans without calling OpenAI.

When you are ready to use the real OpenAI API, change the backend `env.json` to:

```json
"AI_MODE": "openai",
"OPENAI_API_KEY": "sk-proj-your-real-key"
```

After changing `backend/env.json`, stop and restart SAM local:

```bash
sam local start-api --env-vars env.json
```

Start the local Lambda API:

```bash
sam build
sam local start-api --env-vars env.json
```

Backend URL:

```text
http://localhost:3000
```

Test:

```bash
curl http://localhost:3000/health
```

### Terminal 2 — frontend

```bash
cd cloudmentor-serverless/frontend
npm install
cp .env.example .env
```

Edit `.env`. The file includes local, EC2, and API Gateway examples. For local laptop mode, keep only this active line:

```env
VITE_API_BASE_URL=http://localhost:3000
```

The same `.env.example` also includes commented production examples:

```env
# EC2 mode
# VITE_API_BASE_URL=http://YOUR_EC2_PUBLIC_IP/api

# Full AWS serverless mode
# VITE_API_BASE_URL=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com
```

Run:

```bash
npm run dev
```

Open:

```text
http://localhost:5173
```

### Test the learning UI

1. Paste notes into the textarea.
2. Click **Generate Quiz** and answer the MCQs. The UI will show correct and wrong answers immediately.
3. Click **Create Flashcards** and flip through the cards using Previous/Next.
4. Click **Build Study Plan**, set `Study days` to any number from 1 to 30, and verify the output contains exactly that many days.
5. Upload a `.txt`, `.md`, `.csv`, `.json`, `.yaml`, or `.log` file and confirm the extracted text loads into the notes area.

---

## 8. Run locally but store uploaded files in S3

Use this when you want your laptop to run the API locally while uploaded files go to a real S3 bucket.

### Step 1 — create S3 and DynamoDB resources

From the project root:

```bash
chmod +x scripts/create-ec2-aws-resources.sh
AWS_REGION=ap-southeast-1 \
BUCKET_NAME=cloudmentor-materials-yourname-dev \
TABLE_NAME=cloudmentor-history-dev \
CORS_ORIGIN='*' \
./scripts/create-ec2-aws-resources.sh
```

Bucket names must be globally unique across AWS.

### Step 2 — configure backend env

```bash
cd backend
cp env.ec2.example.json env.json
```

Edit `env.json`:

```json
{
  "CloudMentorFunction": {
    "AI_MODE": "mock",
    "OPENAI_API_KEY": "",
    "OPENAI_MODEL": "gpt-4.1-mini",
    "TABLE_NAME": "cloudmentor-history-dev",
    "MATERIALS_BUCKET": "cloudmentor-materials-yourname-dev",
    "CORS_ORIGIN": "*",
    "STORAGE_MODE": "s3",
    "LOCAL_DEV": "false",
    "AWS_REGION": "ap-southeast-1"
  }
}
```

Start backend:

```bash
npm install
sam build
sam local start-api --env-vars env.json
```

Frontend remains:

```env
VITE_API_BASE_URL=http://localhost:3000
```

Now file uploads from your local browser are stored in S3.

---

## 9. Create an EC2 machine for classroom hosting

Recommended EC2 setup:

```text
AMI: Ubuntu Server 24.04 LTS or Ubuntu Server 22.04 LTS
Instance type: t3.medium or t3.small for smoother Docker/SAM usage
Storage: 20 GB gp3 or larger
Key pair: create or use an existing .pem key
```

Security group inbound rules:

```text
SSH   TCP 22  Your IP only
HTTP  TCP 80  0.0.0.0/0
HTTPS TCP 443 Optional, if you add SSL later
```

You do not need to expose port `3000` publicly because Nginx will proxy `/api` to `127.0.0.1:3000` inside the EC2 machine.

### Recommended IAM role for EC2

Attach an IAM role to the EC2 instance with permission to use:

```text
S3 bucket used by CloudMentor
DynamoDB table used by CloudMentor
CloudWatch logs, optional
```

For a quick classroom demo, you can use broader managed policies, but for production use a least-privilege policy limited to your exact S3 bucket and DynamoDB table.

---

## 10. SSH into EC2

From your laptop:

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@EC2_PUBLIC_IP
```

Update the system:

```bash
sudo apt-get update -y
sudo apt-get upgrade -y
```

---

## 11. Install CloudMentor prerequisites on EC2

Copy or clone the project onto EC2, then run:

```bash
cd cloudmentor-serverless
chmod +x scripts/ec2-bootstrap.sh
./scripts/ec2-bootstrap.sh
```

The bootstrap script installs:

```text
Node.js
npm
Docker
AWS CLI v2
AWS SAM CLI
Nginx
Git/Rsync/Unzip
```

Important: after bootstrap finishes, log out and SSH back in so Docker group permission is refreshed.

```bash
exit
ssh -i your-key.pem ubuntu@EC2_PUBLIC_IP
```

---

## 12. Create S3 and DynamoDB for EC2 mode

On your laptop or on EC2, run this from the project root after AWS CLI is configured or the EC2 role is attached:

```bash
AWS_REGION=ap-southeast-1 \
BUCKET_NAME=cloudmentor-materials-yourname-ec2 \
TABLE_NAME=cloudmentor-history-ec2 \
CORS_ORIGIN="http://EC2_PUBLIC_IP" \
./scripts/create-ec2-aws-resources.sh
```

This script creates/configures:

```text
Private S3 bucket
S3 block public access
S3 server-side encryption
S3 CORS for file upload
DynamoDB table with userId + createdAtId keys
```

---

## 13. Deploy CloudMentor manually on EC2

From the project root on EC2:

```bash
export PUBLIC_HOST=EC2_PUBLIC_IP
export PUBLIC_FRONTEND_ORIGIN=http://EC2_PUBLIC_IP
export FRONTEND_API_BASE_URL=http://EC2_PUBLIC_IP/api
export AI_MODE=mock
export OPENAI_API_KEY=
export OPENAI_MODEL=gpt-4.1-mini
export AWS_REGION=ap-southeast-1
export STORAGE_MODE=s3
export MATERIALS_BUCKET=cloudmentor-materials-yourname-ec2
export TABLE_NAME=cloudmentor-history-ec2

./scripts/ec2-deploy.sh
```

The script does this:

```text
1. Writes backend/env.ec2.json
2. Installs backend packages
3. Runs sam build
4. Starts SAM local API as a systemd service on 127.0.0.1:3000
5. Builds the React frontend with VITE_API_BASE_URL=http://EC2_PUBLIC_IP/api
6. Copies frontend/dist to /var/www/cloudmentor
7. Configures Nginx to serve React from http://EC2_PUBLIC_IP
8. Configures Nginx to proxy /api/* to the backend
```

Open the app:

```text
http://EC2_PUBLIC_IP
```

Test backend through Nginx:

```bash
curl http://EC2_PUBLIC_IP/api/health
```

Check backend logs:

```bash
sudo journalctl -u cloudmentor-api -f
```

Restart backend manually:

```bash
sudo systemctl restart cloudmentor-api
```

---

## 14. GitHub Actions CI/CD to EC2

This project includes:

```text
.github/workflows/deploy-ec2.yml
```

When you push to the `main` branch, GitHub Actions will:

```text
1. Connect to EC2 over SSH
2. Sync the latest code to /opt/cloudmentor or your configured app directory
3. Rebuild the backend with SAM
4. Restart the backend systemd service
5. Rebuild the React frontend
6. Copy the new frontend build to Nginx
7. Serve the latest app from http://EC2_PUBLIC_IP
```

### Required GitHub repository secrets for EC2 deployment

Go to:

```text
GitHub repository → Settings → Secrets and variables → Actions → New repository secret
```

Add:

```text
EC2_HOST              EC2 public IPv4 address, for example 13.229.xx.xx
EC2_USER              ubuntu
EC2_SSH_KEY           private key content, including BEGIN/END lines
EC2_APP_DIR           /opt/cloudmentor
AI_MODE               mock for classroom demo, openai for real OpenAI calls
OPENAI_API_KEY        your OpenAI API key, required only when AI_MODE=openai
OPENAI_MODEL          gpt-4.1-mini
AWS_REGION            ap-southeast-1
MATERIALS_BUCKET      cloudmentor-materials-yourname-ec2
TABLE_NAME            cloudmentor-history-ec2
STORAGE_MODE          s3
```

For `EC2_SSH_KEY`, paste the full private key text:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

After secrets are configured:

```bash
git add .
git commit -m "Update CloudMentor"
git push origin main
```

Then open:

```text
http://EC2_PUBLIC_IP
```

---

## 15. Optional CI/CD for real AWS Lambda backend

This project also includes:

```text
.github/workflows/deploy-serverless-backend.yml
```

This workflow deploys the real AWS serverless backend with SAM:

```text
API Gateway
AWS Lambda
S3 bucket
DynamoDB table
IAM permissions
```

Required GitHub repository secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
OPENAI_API_KEY
OPENAI_MODEL
AI_MODE
CORS_ORIGIN
SAM_STACK_NAME
```

Run it from:

```text
GitHub → Actions → Deploy Serverless Backend to AWS → Run workflow
```

Or push backend changes to `main`.

After deployment, get the API URL from CloudFormation/SAM output:

```bash
aws cloudformation describe-stacks \
  --stack-name cloudmentor \
  --query "Stacks[0].Outputs" \
  --output table
```

If you want EC2 frontend to call the real Lambda API instead of the EC2 SAM-local backend, set:

```text
FRONTEND_API_BASE_URL=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com
```

Then rerun:

```bash
./scripts/ec2-deploy.sh
```

---

## 16. Deploy backend manually to real AWS Lambda

From your laptop:

```bash
cd backend
npm install
sam build
sam deploy --guided
```

Recommended values:

```text
Stack Name: cloudmentor
AWS Region: ap-southeast-1
Parameter OpenAiApiKey: your OpenAI API key
Parameter OpenAiModel: gpt-4.1-mini
Parameter CorsOrigin: * for classroom demo, or http://EC2_PUBLIC_IP when using EC2 frontend
Confirm changes before deploy: Y
Allow SAM CLI IAM role creation: Y
Disable rollback: N
Save arguments to samconfig.toml: Y
```

SAM deploy creates and updates the AWS resources. Your Lambda code is packaged from the `backend` folder and pushed to AWS through CloudFormation.

Expected outputs:

```text
ApiBaseUrl = https://abc123.execute-api.ap-southeast-1.amazonaws.com
MaterialsBucketName = cloudmentor-cloudmentormaterialsbucket-xxxx
TableName = cloudmentor-CloudMentorTable-xxxx
```

---

## 17. Which URL should I use?

### Local laptop mode

```env
VITE_API_BASE_URL=http://localhost:3000
```

Frontend runs at:

```text
http://localhost:5173
```

### EC2 mode with Nginx proxy

```env
VITE_API_BASE_URL=http://EC2_PUBLIC_IP/api
```

Frontend runs at:

```text
http://EC2_PUBLIC_IP
```

### EC2 frontend calling real AWS Lambda

```env
VITE_API_BASE_URL=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com
```

Frontend still runs at:

```text
http://EC2_PUBLIC_IP
```

---

## 18. How the frontend is served from EC2

The React app is not running with `npm run dev` in EC2 production/classroom mode.

Instead:

```text
npm run build
  ↓
frontend/dist
  ↓
/var/www/cloudmentor
  ↓
Nginx
  ↓
http://EC2_PUBLIC_IP
```

Nginx also proxies API calls:

```text
http://EC2_PUBLIC_IP/api/health
  ↓
Nginx
  ↓
http://127.0.0.1:3000/health
  ↓
SAM local Lambda backend
```

---

## 19. How Lambda code is pushed

### SAM local mode

```bash
sam local start-api
```

This does not push anything to AWS. It runs the Lambda code locally inside Docker.

### Real AWS Lambda mode

```bash
sam build
sam deploy
```

This packages the backend code and deploys it to AWS Lambda through CloudFormation.

The Lambda handler is configured in `backend/template.yaml`:

```yaml
CodeUri: .
Handler: src/app.handler
```

Meaning:

```text
Take backend code from this folder
Use handler function from backend/src/app.mjs
```

---

## 20. Supported uploads

CloudMentor stores any uploaded file under the demo size limit, but auto-loads text only from:

```text
.txt
.md
.markdown
.csv
.json
.yaml
.yml
.log
```

PDF/DOCX files are stored, but this classroom version does not extract text from them yet. Students can add PDF extraction later using another Lambda, Amazon Textract, or a document parser.

---

## 21. Important security notes

- Never put the OpenAI API key in the React frontend.
- React `.env` values are visible in the browser build.
- Keep the OpenAI API key only in Lambda, EC2 server environment, SAM parameter, or GitHub secret.
- Do not commit `backend/env.json`, `backend/env.ec2.json`, or any other backend `env.*.json` file that contains secrets.
- For production, replace `CorsOrigin: *` with the real frontend origin.
- Use HTTPS for production.
- Add Cognito or another auth layer before real student usage.
- Add stricter file validation and malware scanning before production.
- Use least-privilege IAM instead of broad demo permissions.

---

## 22. Troubleshooting

### `zsh: command not found: sam`

Install AWS SAM CLI, then verify:

```bash
sam --version
```

### Docker permission error on EC2

Run:

```bash
sudo usermod -aG docker ubuntu
exit
```

Then SSH back into the EC2 machine.

### Frontend opens but API fails

Check:

```bash
curl http://EC2_PUBLIC_IP/api/health
sudo systemctl status cloudmentor-api
sudo journalctl -u cloudmentor-api -f
```

### S3 upload fails from browser

Check S3 CORS:

```bash
aws s3api get-bucket-cors --bucket YOUR_BUCKET_NAME
```

Make sure `CORS_ORIGIN` matches:

```text
http://EC2_PUBLIC_IP
```

For quick classroom testing, you can use:

```text
*
```

### DynamoDB history does not save

Check:

```bash
aws dynamodb describe-table --table-name YOUR_TABLE_NAME --region YOUR_REGION
```

Make sure the EC2 IAM role or AWS CLI credentials can write to the table.

---

## 23. Clean up AWS resources

If you deployed the SAM backend:

```bash
cd backend
sam delete
```

If you created EC2 classroom resources manually:

```bash
aws s3 rm s3://YOUR_BUCKET_NAME --recursive
aws s3api delete-bucket --bucket YOUR_BUCKET_NAME --region YOUR_REGION
aws dynamodb delete-table --table-name YOUR_TABLE_NAME --region YOUR_REGION
```

Stop or terminate the EC2 instance if class is finished.

---

## 24. Teaching roadmap

Suggested teaching sequence:

```text
Day 1: React UI and API calls
Day 2: Lambda handler and routes
Day 3: OpenAI prompt design
Day 4: Upload flow and S3 pre-signed URLs
Day 5: DynamoDB history
Day 6: Local SAM and EC2 hosting
Day 7: GitHub Actions CI/CD
Day 8: Real AWS Lambda deployment with SAM
```

---

## Fix: npm install tries to download from an internal registry

If `npm install` fails with a URL similar to:

```bash
packages.applied-caas-gateway1.internal.api.openai.org
```

that means your `package-lock.json` or npm registry is pointing to an internal package mirror that your laptop cannot access.

Run this from both `backend` and `frontend` if needed:

```bash
npm config set registry https://registry.npmjs.org/
npm config delete proxy
npm config delete https-proxy
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

The project includes `.npmrc` files that force the public npm registry:

```bash
registry=https://registry.npmjs.org/
```

Do not commit `backend/env.json` because it contains your OpenAI API key.
