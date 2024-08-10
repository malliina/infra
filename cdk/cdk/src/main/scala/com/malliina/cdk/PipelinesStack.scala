package com.malliina.cdk

import com.malliina.cdk.CloudWatchLambda.CWConf
import software.amazon.awscdk.pipelines.{CodePipelineSource, ShellStep}
import software.amazon.awscdk.{Stack, Stage}
import software.constructs.Construct

/** Uses CDK Pipelines.
  */
class PipelinesStack(scope: Construct, stackName: String)
  extends Stack(scope, stackName, CDK.stackProps)
  with CDKSyntax:
  val stack = this
  val cdkVersion = BuildInfo.cdkVersion
  val source = codeCommit(stack, "Source"): builder =>
    builder
      .repositoryName(getStackName)
      .description(s"Code for $getStackName.")
  val jarTarget = "jartarget"
  val pipeline = codePipeline(stack, "Pipeline"): p =>
    p.pipelineName(getStackName)
      .synth(
        ShellStep.Builder
          .create("Synth")
          .input(CodePipelineSource.codeCommit(source, "master"))
          .commands(list("./cdk/build.sh"))
          .env(map("CDK_VERSION" -> BuildInfo.cdkVersion, "OUTPUT_DIR" -> jarTarget))
          .build()
      )

  pipeline.addStage(MultiStage(stack, "lambdas", jarTarget))

class MultiStage(scope: Construct, id: String, jarTarget: String) extends Stage(scope, id):
  val logsHandler = CloudWatchLambda(this, CWConf("cloudwatch-processor"), jarTarget)
  // Add more lambdas here
