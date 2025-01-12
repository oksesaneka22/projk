#!/bin/bash

# Define variables
JENKINS_URL="http://localhost:8080"
JENKINS_CLI="/var/lib/jenkins/jenkins-cli.jar"
JENKINS_WAR_URL="https://updates.jenkins-ci.org/download/war/latest/jenkins.war"  # URL for Jenkins WAR file
PLUGINS=(
  "folders"
  "antisamy-markup-formatter"
  "build-timeout"
  "credentials-binding"
  "timestamper"
  "ws-cleanup"
  "ant"
  "gradle"
  "workflow-aggregator"
  "github-branch-source"
  "pipeline-github-lib"
  "pipeline-stage-view"
  "git"
  "ssh-slaves"
  "matrix-auth"
  "pam-auth"
  "ldap"
  "email-ext"
  "mailer"
)

# Function to install Jenkins
install_jenkins() {
  echo "Installing Jenkins..."

  # Install Jenkins using the appropriate method (example for Debian/Ubuntu)
  sudo apt update
  sudo apt install default-jre -y
  sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
  sudo apt-get update -y
  sudo dpkg --configure -a
  sudo apt-get install fontconfig openjdk-17-jre -y
  sudo apt-get install jenkins -y


  echo "Jenkins installation completed."
}

# Wait for Jenkins to start
wait_for_jenkins() {
  echo "Waiting for Jenkins to initialize..."
  sleep 60
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
}


# Function to create the first admin user
create_admin_user() {
  # Get Jenkins initial admin password
  ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
  echo "Using admin password: $ADMIN_PASSWORD"

  # Download Jenkins CLI if not already downloaded
  if [ ! -f "$JENKINS_CLI" ]; then
    wget -q $JENKINS_URL/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI
  fi

  # Create the admin user using the Jenkins CLI
  echo "Creating the first admin user..."
  java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD create-user --username admin --password admin --fullname "Admin" --email "admin@example.com"
}

# Install Jenkins
install_jenkins

# Wait for Jenkins to initialize
wait_for_jenkins

# Create the first admin user
create_admin_user

# Install plugins
for plugin in "${PLUGINS[@]}"; do
  echo "Installing plugin: $plugin"
  java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD install-plugin $plugin || {
    echo "Failed to install plugin $plugin. Retrying..."
    sleep 120
    java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD install-plugin $plugin
  }
done

# Restart Jenkins to apply changes
echo "Restarting Jenkins to apply plugin changes..."
java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD safe-restart

echo "All plugins installed successfully."
