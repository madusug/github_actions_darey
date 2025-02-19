# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 23

# Verify the Node.js version:
node -v # Should print "v23.8.0".
nvm current # Should print "v23.8.0".

# Verify npm version:
npm -v # Should print "10.9.2".

