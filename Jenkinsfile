pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment to spin up or tear down')
        choice(name: 'ACTION', choices: ['Plan Only', 'Apply (Deploy)', 'Destroy (Teardown)'], description: 'Action to perform')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region for resources')
        string(name: 'TF_STATE_BUCKET', defaultValue: 'platform-terraform-state-bucket', description: 'S3 Bucket for Terraform state')
        string(name: 'TF_STATE_LOCK_TABLE', defaultValue: 'platform-terraform-state-locks', description: 'DynamoDB table for state locking')
        string(name: 'CLUSTER_NAME', defaultValue: 'platform-eks-cluster', description: 'Name of EKS Cluster')
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        // AWS credentials profile or credentials ID configured in Jenkins
        AWS_CRED_ID        = 'aws-platform-credentials'
        
        // Terraform input variables passed via environment
        TF_VAR_environment = "${params.ENVIRONMENT}"
        TF_VAR_aws_region  = "${params.AWS_REGION}"
        TF_VAR_cluster_name = "${params.CLUSTER_NAME}"
    }

    options {
        timeout(time: 2, unit: 'HOURS')
    }

    stages {
        stage('Tool Check & Validation') {
            steps {
                script {
                    echo "Checking build prerequisites..."
                    sh "chmod +x scripts/*.sh"
                    sh "./scripts/check-prereqs.sh"
                }
            }
        }

        stage('Bootstrap Backend') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    echo "Bootstrapping remote state backend (S3)..."
                    sh "./scripts/bootstrap-backend.sh ${params.TF_STATE_BUCKET} ${params.AWS_REGION}"
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        echo "Initializing Terraform with remote S3 backend..."
                        sh """
                            terraform init \
                                -backend-config="bucket=${params.TF_STATE_BUCKET}" \
                                -backend-config="key=environments/${params.ENVIRONMENT}/terraform.tfstate" \
                                -backend-config="region=${params.AWS_REGION}" \
                                -reconfigure
                        """
                    }
                }
            }
        }

        stage('Lint & Security Scan') {
            steps {
                dir('terraform') {
                    echo "Running Terraform Lint and Format checks..."
                    sh "terraform fmt -check"
                    
                    script {
                        // Optional security scanners check
                        if (sh(script: 'command -v tfsec', returnStatus: true) == 0) {
                            echo "Running tfsec scan..."
                            sh "tfsec ."
                        } else if (sh(script: 'command -v checkov', returnStatus: true) == 0) {
                            echo "Running checkov scan..."
                            sh "checkov -d ."
                        } else {
                            echo "⚠️ Security scanners (tfsec/checkov) not found on agent. Skipping security checks."
                        }
                    }
                }
                
                script {
                    echo "Linting Helm charts..."
                    sh "helm lint helm/platform-charts"
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        script {
                            if (params.ACTION == 'Destroy (Teardown)') {
                                echo "Generating Destroy Plan..."
                                sh "terraform plan -destroy -out=tfdestroy.plan"
                            } else {
                                echo "Generating Apply Plan..."
                                sh "terraform plan -out=tfapply.plan"
                            }
                        }
                    }
                }
            }
        }

        stage('Manual Approval Gate') {
            when {
                expression { params.ACTION != 'Plan Only' }
            }
            steps {
                script {
                    // Force approval for staging/production or teardown operations
                    if (params.ENVIRONMENT != 'dev' || params.ACTION == 'Destroy (Teardown)') {
                        input message: "Approve deployment of ${params.ACTION} to ${params.ENVIRONMENT}?", ok: "Proceed"
                    } else {
                        echo "Auto-approving apply for 'dev' environment..."
                    }
                }
            }
        }

        stage('Terraform Execute') {
            when {
                expression { params.ACTION != 'Plan Only' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        script {
                            if (params.ACTION == 'Apply (Deploy)') {
                                echo "Applying Terraform Plan..."
                                sh "terraform apply -auto-approve tfapply.plan"
                            } else if (params.ACTION == 'Destroy (Teardown)') {
                                echo "Executing Infrastructure Teardown..."
                                sh "terraform apply -auto-approve tfdestroy.plan"
                            }
                        }
                    }
                }
            }
        }

        stage('Helm Platform Config') {
            when {
                expression { params.ACTION == 'Apply (Deploy)' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        echo "Updating Kubeconfig for EKS..."
                        sh "aws eks update-kubeconfig --name ${params.ENVIRONMENT}-${params.CLUSTER_NAME} --region ${params.AWS_REGION}"
                        
                        // Extract output variables from Terraform output
                        def executionRoleArn = sh(script: "terraform -chdir=terraform output -raw emr_execution_role_arn", returnStdout: true).trim()
                        def emrNamespace = sh(script: "terraform -chdir=terraform output -raw emr_namespace", returnStdout: true).trim() || 'emr-jobs'
                        
                        echo "Deploying Helm configurations for EMR on EKS Namespace: ${emrNamespace}..."
                        sh """
                            helm upgrade --install platform-charts ./helm/platform-charts \
                                --namespace ${emrNamespace} \
                                --create-namespace \
                                --set global.environment=${params.ENVIRONMENT} \
                                --set global.awsRegion=${params.AWS_REGION} \
                                --set emrOnEks.namespace=${emrNamespace} \
                                --set emrOnEks.awsIamRoleArn=${executionRoleArn}
                        """
                    }
                }
            }
        }

        stage('Smoke Tests & Verification') {
            when {
                expression { params.ACTION == 'Apply (Deploy)' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.AWS_CRED_ID, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        def virtualClusterId = sh(script: "terraform -chdir=terraform output -raw emr_virtual_cluster_id", returnStdout: true).trim()
                        
                        echo "Running deployment verification tests..."
                        sh "./scripts/verify-deployment.sh ${params.ENVIRONMENT}-${params.CLUSTER_NAME} ${params.AWS_REGION} ${virtualClusterId}"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning up local build workspace artifacts..."
            sh "rm -f terraform/*.plan"
        }
        success {
            echo "Pipeline succeeded! Environment ${params.ENVIRONMENT} update completed: ${params.ACTION}."
        }
        failure {
            echo "Pipeline failed! Please review console log outputs above."
        }
    }
}
