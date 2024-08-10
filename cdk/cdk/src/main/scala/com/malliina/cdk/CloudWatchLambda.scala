package com.malliina.cdk

import com.malliina.cdk.CloudWatchLambda.CWConf
import software.amazon.awscdk.services.lambda.{Code, Function as LambdaFunction, Runtime as LambdaRuntime}
import software.amazon.awscdk.{Stack, Duration as AWSDuration}
import software.constructs.Construct

object CloudWatchLambda:
  case class CWConf(stackName: String)

class CloudWatchLambda(scope: Construct, conf: CWConf, jarTarget: String)
  extends Stack(scope, conf.stackName, CDK.stackProps)
  with CDKSyntax:
  val stack = this
  val assetCode = Code.fromAsset(jarTarget)
  val function = LambdaFunction.Builder
    .create(stack, "Function")
    .handler("com.malliina.aws.CloudWatchHandler")
    .runtime(LambdaRuntime.JAVA_21)
    .code(assetCode)
    .memorySize(512)
    .timeout(AWSDuration.seconds(180))
    .build()
