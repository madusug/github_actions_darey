# GITHUB ACTIONS

This project focuses on the built in CI/CD platform for github, GITHUB Actions.

First, we were asked to create a simple server using express.js to serve a static page. I created a directory `mkdir my-express-server` and cd'd into it. I ran `npm init -y` but it didn't work. So I installed Node.js first using 
```
# Download and install fnm:
curl -o- https://fnm.vercel.app/install | bash

# Download and install Node.js:
fnm install 22

# Verify the Node.js version:
node -v # Should print "v22.14.0".

# Verify npm version:
npm -v # Should print "10.9.2".
```

This successfully installed npm and node. I then proceeded to install express using `npm install express`. Next, I set up my project structure as follows:
```
my-express-server
├── public
│   └── index.html
└── server.js
```
I then edited the contents of the static web page, "index.html", as follows:
```
<!DOCTYPE html>
<html>
<head>
  <title>Simple Express.js Server</title>
</head>
<body>
  <h1>Hello, this is a static web page served by Express!</h1>
</body>
</html>
```

Next, I edited the contents of the server.js file as follows:
```
const express = require('express');
const app = express();
const port = 3000;

// Serve static files from the "public" directory
app.use(express.static('public'));

// Start the server
app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
```

Next, in GitHub, I went to Actions -> New Workflow and searched for a workflow to do a clean installation of node dependencies, cache/restore them, build the source code and run tests across different versions of node. After configuring the workflow I found, github created a node.js.yml file for me in the .github/workflows directory. The file had the following content.
```
name: Node.js CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:

    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x, 22.x]
        # See supported Node.js release schedule at https://nodejs.org/en/about/releases/

    steps:
    - uses: actions/checkout@v4
    - name: Use Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'
    - run: npm ci
    - run: npm run build --if-present
    - run: npm test
```
After successfully running the workflow, I decided to go even further I decided to edit my workflow to build images and send them to the docker repository.
```
# This workflow will do a clean installation of node dependencies, cache/restore them, build the source code and run tests across different versions of node
# For more information see: https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-nodejs

name: Node.js CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:

    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x, 22.x]
        # See supported Node.js release schedule at https://nodejs.org/en/about/releases/

    steps:
    - uses: actions/checkout@v4
    - name: Use Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'
    - run: npm ci
    - run: npm run build --if-present
    - run: npm test
    - uses: mr-smithers-excellent/docker-build-push@v6
      name: Build & push Docker image
      with:
        image: distinctugo/darey-github-actions
        tags: v1, v2, latest
        registry: docker.io
        dockerfile: Dockerfile
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}

    
```
For this to work, I discovered that I had to store my docker username and password as secrets on github. Thus allowing the values to be passed when running the workflow. This led to success.

Next, I decided to deploy to the cloud using aws. I proceeded to search for the right workflow in github actions to build and push a new container image to Amazon ECR, and then deploy a new task definition to Amazon ECS, when the previous job "node.js.yml" is complete.

To accomplish this, I had to:
1. Create an ECR repository to store images
   a. For example: `aws ecr create-repository --repository-name my-ecr-repo --region us-east-2`.
   b. Replace the value of the `ECR_REPOSITORY` environment variable in the workflow below with your repository's name.
   c. Replace the value of the `AWS_REGION` environment variable in the workflow below with your repository's region.
2. Create an ECS task definition, an ECS cluster, and an ECS service.
   a. For example, follow the Getting Started guide on the ECS console: https://us-east-2.console.aws.amazon.com/ecs/home?region=us-east-2#/firstRun
    b. Replace the value of the `ECS_SERVICE` environment variable in the workflow below with the name you set for the Amazon ECS service.
    c. Replace the value of the `ECS_CLUSTER` environment variable in the workflow below with the name you set for the cluster.
3. Store your ECS task definition as a JSON file in your repository.
    a. The format should follow the output of `aws ecs register-task-definition --generate-cli-skeleton`.
    b. Replace the value of the `ECS_TASK_DEFINITION` environment variable in the workflow below with the path to the JSON file.
    c. Replace the value of the `CONTAINER_NAME` environment variable in the workflow below with the name of the container in the `containerDefinitions` section of the task definition.
4. Store an IAM user access key in GitHub Actions secrets named `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

This workflow created a file "aws.yml" in my .github/workflows directory with my edits:
```
name: Deploy to Amazon ECS

on:
  workflow_run:
    workflows: ["Node.js CI"]
    types:
      - completed  # Ensures Workflow A completes before triggering this workflow

env:
  AWS_REGION: us-east-1                           # set this to your preferred AWS region, e.g. us-west-1
  ECR_REPOSITORY: githubactions/npm_application           # set this to your Amazon ECR repository name
  ECS_SERVICE: github-actions-service                 # set this to your Amazon ECS service name
  ECS_CLUSTER: git_actions_darey                 # set this to your Amazon ECS cluster name
  ECS_TASK_DEFINITION: .aws/darey-github-actions-task-definition-revision1.json       # set this to the path to your Amazon ECS task definition
                                               # file, e.g. .aws/task-definition.json
  CONTAINER_NAME: github-actions-container           # set this to the name of the container in the
                                               # containerDefinitions section of your task definition

permissions:
  contents: read

jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1

    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        # Build a docker container and
        # push it to ECR so that it can
        # be deployed to ECS.
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: ${{ env.ECS_TASK_DEFINITION }}
        container-name: ${{ env.CONTAINER_NAME }}
        image: ${{ steps.build-image.outputs.image }}

    - name: Deploy Amazon ECS task definition
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: ${{ steps.task-def.outputs.task-definition }}
        service: ${{ env.ECS_SERVICE }}
        cluster: ${{ env.ECS_CLUSTER }}
        wait-for-service-stability: true
```

I also had to store my AWS Access key ID and Secret Key in Secrets on GitHub.
This successfully deployed my image to AWS.