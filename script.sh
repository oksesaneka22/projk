#!/bin/bash

# Define variables
JENKINS_URL="http://localhost:8080"
JENKINS_CLI="/var/lib/jenkins/jenkins-cli.jar"
JENKINS_WAR_URL="https://updates.jenkins-ci.org/download/war/latest/jenkins.war"  # URL for Jenkins WAR file
PLUGINS=(
  "cloudbees-folder"
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

# Function to download Jenkins CLI if not already present
download_jenkins_cli() {
  if [ ! -f "$JENKINS_CLI" ]; then
    echo "Downloading Jenkins CLI..."
    wget -q $JENKINS_URL/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI
  fi
}

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

# Disable Jenkins setup wizard
disable_setup_wizard() {
  echo "Disabling Jenkins setup wizard..."
  sudo sed -i 's/^JAVA_ARGS=.*/JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"/' /etc/default/jenkins
}

# Wait for Jenkins to start
wait_for_jenkins() {
  echo "Waiting for Jenkins to initialize..."
  sleep 60
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
}

# Function to create the first admin user using Groovy script
create_admin_user() {
  echo "Creating the first admin user..."

  # Jenkins CLI requires the initial admin password, typically stored in /var/lib/jenkins/secrets/initialAdminPassword
  INITIAL_ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

  # Wait for Jenkins to be available, if not ready yet
  while ! curl -s $JENKINS_URL > /dev/null; do
    echo "Waiting for Jenkins to become available..."
    sleep 5
  done

  # Run the Groovy script to create the admin user
  java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$INITIAL_ADMIN_PASSWORD groovy = <<EOF
import jenkins.model.*
import hudson.security.*

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
def user = hudsonRealm.createAccount("admin", "admin")  // Change "admin" to desired username/password
user.save()

// Set the security realm
Jenkins.instance.setSecurityRealm(hudsonRealm)

// Set a simpler authorization strategy
Jenkins.instance.setAuthorizationStrategy(new FullControlOnceLoggedInAuthorizationStrategy())

// Grant admin rights to the created user
Jenkins.instance.save()

EOF

  echo "Admin user created successfully."
}

# Function to install plugins
install_plugins() {
  for plugin in "${PLUGINS[@]}"; do
    echo "Installing plugin: $plugin"
    java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:admin install-plugin $plugin || {
      echo "Failed to install plugin $plugin. Retrying..."
      sleep 120
      java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:admin install-plugin $plugin
    }
  done
}

# Install Jenkins
install_jenkins

# Disable the setup wizard
disable_setup_wizard

# Wait for Jenkins to initialize
wait_for_jenkins

# Download Jenkins CLI if not present
download_jenkins_cli

# Create the first admin user
create_admin_user

# Install plugins
install_plugins

# Restart Jenkins to apply changes
echo "Restarting Jenkins to apply plugin changes..."
java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:admin safe-restart

echo "All plugins installed successfully."
