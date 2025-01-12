#!/bin/bash

# Define variables
JENKINS_VERSION="lts"
PLUGINS=("git" "workflow-aggregator" "blueocean" "credentials" "pipeline-stage-view")
JENKINS_CLI="/var/lib/jenkins/jenkins-cli.jar"
JENKINS_URL="http://localhost:8080"
NEW_USER="ubuntu"
NEW_PASS="ubuntu"

# Update system and install Java
sudo apt update -y
sudo apt install -y openjdk-11-jdk wget gnupg

# Add Jenkins repository and install Jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update -y
sudo apt install -y jenkins

# Start Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 30

# Get the initial admin password
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins initial admin password: $ADMIN_PASSWORD"

# Download Jenkins CLI
wget -q $JENKINS_URL/jnlpJars/jenkins-cli.jar -P /var/lib/jenkins/

# Install Plugins
for plugin in "${PLUGINS[@]}"; do
  java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD install-plugin $plugin
done

# Restart Jenkins to apply plugin changes
java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD safe-restart

# Create a new user
cat <<EOF > create-user.groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def realm = instance.getSecurityRealm()

if (!(realm instanceof HudsonPrivateSecurityRealm)) {
    println("The security realm is not using Jenkins' own database. Exiting.")
    return
}

def user = realm.createAccount("$NEW_USER", "$NEW_PASS")
user.setFullName("New User")
user.save()

println("User '$NEW_USER' created successfully!")
EOF

java -jar $JENKINS_CLI -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD groovy = < create-user.groovy
rm -f create-user.groovy

echo "Jenkins installation, plugin setup, and user creation completed."
