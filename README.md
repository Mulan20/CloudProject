
# Resume Website CI/CD Pipeline with Jenkins, Docker, and AWS

This repository contains the documentation and configuration for a simple HTML resume website deployed using a complete CI/CD pipeline. The project demonstrates a practical implementation of DevOps principles by automating the build, test, and deployment process.

The core technologies used are **Git** for version control, **Docker** for containerization, **Jenkins** for automation, **Docker Hub** as an image registry, and **AWS EC2** for hosting.

## Table of Contents

- [Project Architecture](#project-architecture)
- [Setup and Deployment Guide](#setup-and-deployment-guide)
    - [1. AWS EC2 Instance Setup](#1-aws-ec2-instance-setup)
    - [2. Connecting to the EC2 Instance](#2-connecting-to-the-ec2-instance)
    - [3. Installing and Configuring Git](#3-installing-and-configuring-git)
    - [4. Installing and Setting Up Docker](#4-installing-and-setting-up-docker)
    - [5. Installing and Setting Up Jenkins](#5-installing-and-setting-up-jenkins)
- [Jenkins Pipeline](#jenkins-pipeline)
- [Testing the Deployment](#testing-the-deployment)
- [Challenges and Solutions](#challenges-and-solutions)
- [Conclusion and Future Work](#conclusion-and-future-work)
- [References](#references)

## Project Architecture

The workflow of this project is as follows:

1.  **Code Commit:** A developer pushes changes to the HTML website to a **GitHub** repository.
2.  **Automated Build:** **Jenkins**, running on an AWS EC2 instance, is triggered by the commit. It pulls the latest code from GitHub.
3.  **Containerization:** Jenkins uses a `Dockerfile` to build a new **Docker image** containing the website.
4.  **Image Push:** The newly built image is tagged and pushed to a **Docker Hub** repository.
5.  **Deployment:** Jenkins deploys the new image as a **Docker container** on the same EC2 instance, making the website live.

## Setup and Deployment Guide

This guide outlines the steps to replicate the deployment environment.

### Prerequisites
- An AWS account.
- A local machine or virtual machine with an SSH client.

### 1. AWS EC2 Instance Setup
- Launch a new EC2 instance from the AWS Console.
- **AMI:** Ubuntu (or a similar Debian-based OS).
- **Key Pair:** Create a new key pair and securely save the `.pem` file. This is required for SSH access.
- **Security Group:** Configure the security group to allow inbound traffic on the following ports:
    - **Port 22 (SSH):** For remote access to the instance.
    - **Port 80 (HTTP):** For accessing the deployed website.
    - **Port 8080 (Custom TCP):** For accessing the Jenkins dashboard.

### 2. Connecting to the EC2 Instance
Use an SSH client from your local machine to connect to the EC2 instance. Replace `<your-key.pem>` and `<your-ec2-public-ip>` with your actual values.

```bash
ssh -i /path/to/your-key.pem ubuntu@<your-ec2-public-ip>
```

### 3. Installing and Configuring Git
Once connected to the instance, install Git and configure it with your GitHub credentials.

```bash
# Update the package list
sudo apt-get update

# Install Git
sudo apt-get install git -y

# Verify installation
git --version

# Configure Git
git config --global user.name "Your GitHub Username"
git config --global user.email "Your GitHub Email"
```
It is also recommended to generate an SSH key for GitHub and add it to your account to allow for password-less pushing and pulling.

### 4. Installing and Setting Up Docker
Install Docker on the EC2 instance to manage containers.

```bash
# Install Docker
sudo apt-get install docker.io -y

# Start and enable the Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add the 'ubuntu' user to the 'docker' group to run docker commands without sudo
sudo usermod -aG docker ubuntu
# Important: You must log out and log back in for this change to take effect.
```
Sign up for [Docker Hub](https://hub.docker.com/) and create a **Personal Access Token (PAT)**. This will be used by Jenkins to authenticate with Docker Hub.

### 5. Installing and Setting Up Jenkins
Jenkins requires Java to run. It is recommended to use OpenJDK 17.

```bash
# Install Java (OpenJDK 17)
sudo apt-get install openjdk-17-jre -y

# Verify Java installation
java -version

# Add the Jenkins repository key and source
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list and install Jenkins
sudo apt-get update
sudo apt-get install jenkins -y

# Start and enable the Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins
```
Access Jenkins by navigating to `http://<your-ec2-public-ip>:8080` in your browser. Follow the on-screen instructions to unlock Jenkins and create an admin user.

**Post-Installation Steps:**
1.  **Install Plugins:** Navigate to `Manage Jenkins` > `Plugins` and install the **Git** and **Docker Pipeline** plugins.
2.  **Add Credentials:** Go to `Manage Jenkins` > `Credentials` > `System` > `Global credentials` and add a new credential of type **Username with password**. Use your Docker Hub username and the PAT you generated as the password. Give it an ID like `docker-hub-credentials`.

## Jenkins Pipeline

The pipeline is defined as a "Pipeline script" in the Jenkins job configuration. It automates the entire CI/CD process.

```groovy
pipeline {
    agent any

    environment {
        // Use the ID of the credentials created in Jenkins
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_HUB_REPO = "your-dockerhub-username/jenkins-integration" // Replace with your repo
    }

    stages {
        stage('Checkout') {
            steps {
                // Pull the latest code from the GitHub repository
                git 'https://github.com/your-username/your-repo.git' // Replace with your repo URL
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image using the Dockerfile in the repo
                    sh "docker build -t ${DOCKER_HUB_REPO}:latest ."
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    // Log in to Docker Hub and push the image
                    sh "echo $DOCKER_HUB_CREDENTIALS_PSW | docker login -u $DOCKER_HUB_CREDENTIALS_USR --password-stdin"
                    sh "docker push ${DOCKER_HUB_REPO}:latest"
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    // Stop and remove the old container if it exists
                    sh "docker stop my-resume-app || true"
                    sh "docker rm my-resume-app || true"
                    
                    // Run the new container, mapping port 80 on the host to port 80 in the container
                    sh "docker run -d --name my-resume-app -p 80:80 ${DOCKER_HUB_REPO}:latest"
                }
            }
        }
    }
}
```

## Testing the Deployment

1.  **Test Docker:** After installation, run `docker run hello-world` to verify Docker is working correctly. You can also check its status with `sudo systemctl status docker`.
2.  **Test Jenkins:** Access the Jenkins dashboard at `http://<your-ec2-public-ip>:8080`. You can check its status with `sudo systemctl status jenkins`.
3.  **Test the Website:** Once the Jenkins pipeline has run successfully, your website should be live. You can verify the container is running with `docker ps` and then access the website by navigating to `http://<your-ec2-public-ip>` in your browser.

## Challenges and Solutions

- **EC2 SSH Issues:** Failure to connect to the EC2 instance is often caused by a missing SSH (Port 22) inbound rule in the security group.
- **Pipeline Failures:** Build failures are common during initial setup. The solution is to carefully review the **Console Output** of the failed build in Jenkins, which provides detailed error logs.
- **JDK Version Compatibility:** The latest versions of Jenkins no longer support OpenJDK 11. It is crucial to install **OpenJDK 17** to avoid compatibility issues.
- **AWS Billing:** Accidentally exceeding the free-tier limits can lead to unexpected charges. It's important to monitor resource usage and read AWS free-tier agreements carefully.

## Conclusion and Future Work

This project successfully demonstrates a functional CI/CD pipeline, showcasing how to automate the deployment of a web application using industry-standard tools. The process provides hands-on experience with AWS, Docker, and Jenkins, highlighting the power of automation in reducing manual effort and potential errors.

A potential future improvement would be to configure the Jenkins pipeline to deploy directly to the EC2 instance via SSH, bypassing Docker Hub as an intermediate step. Another key learning is the importance of understanding CI/CD concepts before implementation to streamline the setup process.

## References

- GeeksforGeeks. (2024, July 8). *Building with Docker Using Jenkins Pipelines*. [https://www.geeksforgeeks.org/building-with-docker-using-jenkins-pipelines/](https://www.geeksforgeeks.org/building-with-docker-using-jenkins-pipelines/)
