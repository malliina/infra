package com.malliina.cdk

import com.malliina.cdk.StaticWebsite.StaticConf
import software.amazon.awscdk.services.iam.{AccessKey, AccessKeyStatus, User}
import software.amazon.awscdk.services.s3.Bucket
import software.amazon.awscdk.{CfnOutput, Environment, Stack, StackProps, App as AWSApp}
import software.constructs.Construct

object CDK:
  val stackProps: StackProps =
    StackProps
      .builder()
      .env(Environment.builder().account("490166768057").region("eu-north-1").build())
      .build()

  def main(args: Array[String]): Unit =
    val app = AWSApp()
    val stack = Stack(app, "boat", CDK.stackProps)
    val boat = Infra(stack)
    val static =
      StaticWebsite(StaticConf("cdk.malliina.com", "/global/certificates/arn"), app, "s3-static")
    app.synth()

class Infra(construct: Stack) extends Stack(construct, "boat"):
  val user =
    User.Builder.create(construct, "User").userName("boat-agent").build()
  val agentBucket = Bucket.fromBucketName(construct, "Bucket", "agent.boat-tracker.com")
  agentBucket.grantReadWrite(user)
  val accessKey = AccessKey.Builder
    .create(construct, "AccessKey")
    .status(AccessKeyStatus.ACTIVE)
    .user(user)
    .build()

  outputs(construct)(
    "AccessKeyId" -> accessKey.getAccessKeyId,
    "SecretAccessKey" -> accessKey.getSecretAccessKey.toString
  )

  def outputs(scope: Construct)(kvs: (String, String)*) = kvs.map:
    case (k, v) =>
      CfnOutput.Builder
        .create(scope, k)
        .exportName(k)
        .value(v)
        .build()
