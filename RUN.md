# Jenkins Pipeline Execution Guide

This document provides step-by-step instructions on how to log in to your Jenkins container, configure AWS credentials, and run the infrastructure provisioning pipeline.

---

## 🔑 1. Retrieving Jenkins Credentials

During the initial startup of the Jenkins Docker container, a random administrator password is generated.

### Get Admin Password
Run the following command in your terminal to output the password:
```bash
docker exec platform-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Initial Login Credentials
* **URL**: `http://localhost:8080`
* **Username**: `admin`
* **Password**: *[Paste the string retrieved from the command above]*

---

## ⚙️ 2. Completing the Jenkins Setup Wizard

Upon first login, complete the initialization wizard:
1. **Install Plugins**: Choose **"Install suggested plugins"** (this automatically installs git, credentials, and pipeline plugins).
2. **Create Admin User**: Define your personal username and password to use for future logins.
3. **Jenkins URL**: Save the default `http://localhost:8080/`.

---

## 🔒 3. Adding AWS Credentials to Jenkins

The pipeline uses the ID `aws-platform-credentials` to dynamically load AWS credentials.

1. Go to the Jenkins Dashboard.
2. Navigate to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials (unrestricted)**.
3. Click **Add Credentials** (top right).
4. Configure as follows:
   - **Kind**: `Username with password` (or `AWS Credentials` if the AWS credentials plugin is active)
   - **ID**: `aws-platform-credentials` *(Must match exactly)*
   - **Username**: Your `AWS_ACCESS_KEY_ID`
   - **Password**: Your `AWS_SECRET_ACCESS_KEY`
5. Click **Create**.

---

## 🚀 4. Creating & Launching the Pipeline Job

### A. Create the Job
1. Click **New Item** on the Jenkins homepage.
2. Enter a name: `emr-eks-platform-pipeline`.
3. Select **Pipeline** and click **OK**.

### B. Link SCM Repository
1. Scroll down to the **Pipeline** section.
2. Select **Definition**: `Pipeline script from SCM`.
3. Select **SCM**: `Git`.
4. **Repository URL**: Paste the URL or local file path to this Git repository.
5. **Branch Specifier**: Set to `*/main` (or the branch holding your codebase).
6. **Script Path**: Verify it points to `Jenkinsfile`.
7. Click **Save**.

### C. Trigger the Run
1. Click **Build Now** once. *Note: This first build will fail or terminate within seconds. This is expected behavior as Jenkins requires an initial run to parse parameter definitions from the Jenkinsfile.*
2. Refresh your browser page.
3. Click **Build with Parameters** (which replaces "Build Now").
4. Configure parameters:
   - **`ENVIRONMENT`**: `dev`
   - **`ACTION`**: `Apply (Deploy)`
   - **`AWS_REGION`**: your target region (e.g. `us-east-1`)
5. Click **Build**.
