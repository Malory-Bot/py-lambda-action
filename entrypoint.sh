#!/bin/bash
set -e

echo "###"
echo "# Begin deployment"
echo "###"

install_zip_dependencies(){
    echo "###"
    echo "# Install dependencies to temp python environment, and zip them for upload to AWS"
    echo "###"
    mkdir python
    pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
    zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
    echo "###"
    echo "# Publishing dependcies zip as a layer to lambda function"
    echo "###"
    local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
    echo "# Result:"
    echo $result
    echo "# End Result"
    export LAYER_VERSION=$(jq '.Version' <<< "$result")
    echo "# New layer version: ${LAYER_VERSION}"
    rm -rf python
    rm dependencies.zip
}

publish_function_code(){
    echo "###"
    echo "# Deploying the code from the repository"
    echo "###"
    zip -r code.zip . -x \*.git\*
    aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
    echo "###"
    echo "# Update lambda function to use new layer version (${LAYER_VERSION})"
    echo "###"
    # https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-configuration.html
    aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
    install_zip_dependencies
    publish_dependencies_as_layer
    publish_function_code
    update_function_layers
}

deploy_lambda_function
echo "###"
echo "# Deployment Completed"
echo "###"
