# https://docs.aws.amazon.com/cdk/api/v1/docs/pipelines-readme.html#migrating-from-buildspecyml-files
echo "Building function to $OUTPUT_DIR"
sbt "project lambda" assembly
unzip function.jar -d "$OUTPUT_DIR"
echo "Running synth with CDK $CDK_VERSION"
npm install -g aws-cdk@"$CDK_VERSION"
cdk synth
