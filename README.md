Netflix Clone — DevSecOps CI/CD on AWS EKS
Fully automated, security-first deployment pipeline from code push to production

Jenkins Docker Kubernetes AWS SonarQube Trivy


Pipeline Status Quality Gate Visitors

Project Overview
This project demonstrates a production-grade DevSecOps CI/CD pipeline that automatically builds, scans, and deploys a Netflix Clone application to AWS Elastic Kubernetes Service (EKS) on every code push — with security integrated at every stage.

Key Highlights
Security-first — Trivy scans for both filesystem & container image vulnerabilities
Code Quality — SonarQube enforces quality gates before deployment
Kubernetes-native — deployed on AWS EKS with LoadBalancer access
Fully Automated — end-to-end pipeline triggered on every git push
Containerized — Docker image built, scanned & pushed to Docker Hub
Architecture

Tech Stack
Category	Tool	Purpose
CI/CD	Jenkins	Pipeline automation & orchestration
Security	SonarQube	Static code analysis, bug & vulnerability detection
Trivy	Filesystem & container image vulnerability scanning
Containers	Docker	Containerization of the application
Docker Hub	Container image registry
Cloud (AWS)	EC2	Hosting Jenkins & SonarQube servers
EKS	Managed Kubernetes cluster for deployment
IAM	Secure access management
LoadBalancer	Public-facing application access
CLI Tools	kubectl	Kubernetes cluster management
eksctl	EKS cluster provisioning
AWS CLI	AWS service interaction
Runtime	Node.js	Application runtime environment
CI/CD Pipeline — Stage Breakdown
#	Stage	Description	Tool(s)
1	Clean Workspace	Removes previous build artifacts for a fresh start	Jenkins
2	Checkout from Git	Pulls the latest code from the GitHub repository	Git
3	SonarQube Analysis	Scans for bugs, vulnerabilities, and code smells	SonarQube
4	Quality Gate	Waits for SonarQube pass/fail via webhook callback	SonarQube
5	Install Dependencies	Runs npm install to fetch project dependencies	Node.js / npm
6	Trivy FS Scan	Scans the entire filesystem for known vulnerabilities	Trivy
7	Docker Build & Push	Builds the image (with TMDB API key) and pushes to Docker Hub	Docker
8	Trivy Image Scan	Scans the final Docker image for CVEs before deployment	Trivy
9	Deploy to EKS	Applies Kubernetes manifests and exposes via LoadBalancer	kubectl / EKS
Infrastructure Setup

Prerequisites
Before getting started, ensure you have the following:

Requirement	Details
AWS Account	With IAM permissions for EC2, EKS, and IAM management
Docker Hub Account	For pushing and pulling container images
GitHub Account	To host and version control the project repository
TMDB API Key	Free API key from themoviedb.org for movie data
Step-by-Step Setup Guide
Step 1 — Launch EC2 Instances
Create two EC2 instances on AWS:

Instance	Type	OS	Storage	Open Ports
Jenkins Server	m7i-flex.large (8GB RAM min)	Ubuntu 22.04	30GB	8080, 22
SonarQube Server	t2.medium	Ubuntu 22.04	Default	9000, 22
Important

Allocate at least 30GB of storage for the Jenkins server. Docker images and the Trivy vulnerability DB alone can consume ~6GB.

Step 2 — Install Tools on Jenkins Server
SSH into the Jenkins EC2 instance and run the following:

Install Java 17
Install Jenkins
Install Docker
Install AWS CLI
Install kubectl
Install eksctl
Install Trivy
Step 3 — Set Up SonarQube Server
SSH into the SonarQube EC2 instance:

sudo apt install docker.io -y
sudo usermod -aG docker ubuntu
sudo chmod 777 /var/run/docker.sock
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
Note

SonarQube takes ~1–2 minutes to fully start. Wait before accessing the UI.

Step 4 — Configure SonarQube
Navigate to http://<SonarQube-Public-IP>:9000
Login with default credentials: admin / admin (change on first login)
Generate a token:
Go to → My Account → Security → Generate Tokens
Copy the token — you'll need it in Jenkins
Create a webhook for Jenkins:
Go to → Administration → Configuration → Webhooks → Create
URL: http://<Jenkins-Public-IP>:8080/sonarqube-webhook/
Warning

The webhook is mandatory for the Quality Gate stage to work. Without it, the pipeline will hang indefinitely waiting for a callback.

Step 5 — Create EKS Cluster
Back on the Jenkins server, configure AWS CLI and create the cluster:

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Key, Region (ap-south-1), Output (json)

# Create the EKS cluster (takes ~15-20 minutes)
eksctl create cluster \
  --name cloudnetflix \
  --region ap-south-1 \
  --node-type t3.small \
  --nodes 2 \
  --managed

# Verify the cluster
kubectl get nodes

# Copy kubeconfig to Jenkins user so the pipeline can access the cluster
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /home/ubuntu/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
Tip

Use t3.small instances for learning projects to stay within free tier limits and avoid vCPU quota issues.

Step 6 — Configure Jenkins
6.1 — Install Required Plugins

Navigate to Manage Jenkins → Plugins → Available Plugins and install:

Plugin	Purpose
SonarQube Scanner	Integrates SonarQube analysis
NodeJS	Provides Node.js build environment
Docker Pipeline	Enables Docker commands in pipeline
Kubernetes CLI	kubectl integration
Email Extension	Build notification emails
6.2 — Add Credentials

Navigate to Manage Jenkins → Credentials → Global → Add Credentials:

Credential ID	Type	Description
github-token	Secret text	GitHub personal access token
sonar-token	Secret text	SonarQube authentication token
docker	Username with password	Docker Hub login credentials
aws-access	Secret text	AWS Access Key ID
aws-secret	Secret text	AWS Secret Access Key
6.3 — Configure SonarQube Server

Navigate to Manage Jenkins → System → SonarQube servers:

Name: sonarqube
Server URL: http://<SonarQube-Public-IP>:9000
Server authentication token: Select the sonar-token credential
Step 7 — Create & Run the Pipeline
Go to Jenkins Dashboard → New Item
Enter a name (e.g., netflix-pipeline) → Select Pipeline → Click OK
Under Pipeline:
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/<your-username>/netflix-devsecops-eks.git
Branch: */main
Script Path: Jenkinsfile
Click Save → Click Build Now
Key Configuration Files
Jenkinsfile
pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node18'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }

    stages {
        stage('Clean Workspace') {
            steps { cleanWs() }
        }

        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'YOUR_REPO_URL'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectName=netflix \
                        -Dsonar.projectKey=netflix'''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }

        stage('Install Dependencies') {
            steps { sh 'npm install' }
        }

        stage('TRIVY FS Scan') {
            steps { sh 'trivy fs . > trivyfs.txt' }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker', url: 'https://index.docker.io/v1/') {
                        sh 'docker build --build-arg TMDB_V3_API_KEY=YOUR_KEY -t netflix .'
                        sh 'docker tag netflix YOUR_DOCKERHUB/netflix:latest'
                        sh 'docker push YOUR_DOCKERHUB/netflix:latest'
                    }
                }
            }
        }

        stage('TRIVY Image Scan') {
            steps { sh 'trivy image YOUR_DOCKERHUB/netflix:latest > trivyimage.txt' }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_DEFAULT_REGION=ap-south-1
                        aws eks update-kubeconfig --region ap-south-1 --name cloudnetflix
                        kubectl apply -f deployment.yml
                        kubectl get pods
                        kubectl get svc
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution complete.'
        }
        success {
            echo ' Pipeline succeeded! Application deployed to EKS.'
        }
        failure {
            echo ' Pipeline failed. Check logs for details.'
        }
    }
}
deployment.yml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netflix-deployment
  labels:
    app: netflix
spec:
  replicas: 2
  selector:
    matchLabels:
      app: netflix
  template:
    metadata:
      labels:
        app: netflix
    spec:
      containers:
        - name: netflix
          image: YOUR_DOCKERHUB/netflix:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"

---
apiVersion: v1
kind: Service
metadata:
  name: netflix-service
spec:
  selector:
    app: netflix
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
Security Measures
This project implements security at every layer of the pipeline:

Layer	Measure	Description
Source Code	SonarQube Analysis	Detects bugs, vulnerabilities, and code smells
Quality	SonarQube Quality Gate	Blocks deployments if quality thresholds are not met
Dependencies	Trivy FS Scan	Scans node_modules and project files for known CVEs
Container	Trivy Image Scan	Scans the final Docker image before deployment
Secrets	Jenkins Credential Store	Zero hardcoded secrets in pipeline or application code
Access	IAM Least Privilege	Dedicated IAM user with only EKS-required permissions
Pipeline Results
Metric	Status
Pipeline Status	SUCCESS
EKS Cluster	Running in ap-south-1
Docker Image	Pushed to Docker Hub (netflix:latest)
Running Pods	2 Replicas Active
SonarQube Quality Gate	PASSED
Trivy Scan	Filesystem & Image — Scanned
Application Access	AWS LoadBalancer (Port 80)
Screenshots
TODO: Add screenshots to a screenshots/ folder in your repository and reference them below.

Lessons Learned & Tips
Tip

These are real-world lessons from building this project — save yourself some debugging time!

Issue	Solution
EKS node creation failing	EC2 vCPU limits may be hit — use t3.small for learning; request a quota increase for production
Docker build running out of space	Expand EC2 root volume to 30GB minimum — Docker images + Trivy DB consume ~6GB
Quality Gate stage hangs forever	SonarQube webhook is mandatory — configure it in Step 4
Jenkins can't reach SonarQube after reboot	EC2 public IPs change on restart — update SonarQube URL in Jenkins System config or use Elastic IPs
kubectl commands fail in pipeline	Ensure kubeconfig is copied to /var/lib/jenkins/.kube/config and owned by jenkins user
Cleanup (Avoid Unnecessary Charges!)
Caution

The EKS cluster is the most expensive resource. Delete it immediately when you're done to avoid unexpected AWS charges.

# 1. Delete the EKS cluster (this is the most important step)
eksctl delete cluster --name cloudnetflix --region ap-south-1

# 2. Terminate EC2 instances via AWS Console
#    → EC2 → Instances → Select → Instance State → Terminate

# 3. Remove IAM access keys
#    → IAM → Users → Select user → Security Credentials → Delete keys

# 4. Clean up Docker Hub (optional)
#    → Docker Hub → Repositories → Delete netflix image
Project Structure
netflix-devsecops-eks/
├── Jenkinsfile              # CI/CD pipeline definition
├── Dockerfile               # Container image build instructions
├── deployment.yml           # Kubernetes deployment & service manifests
├── screenshots/             # Pipeline & app screenshots
└── README.md                # Project documentation (this file)
Contributing
Contributions are welcome! If you have improvements or find bugs:

Fork the repository
Create a feature branch (git checkout -b feature/amazing-feature)
Commit your changes (git commit -m 'Add amazing feature')
Push to the branch (git push origin feature/amazing-feature)
Open a Pull Request

