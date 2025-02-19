package com.malliina.cdk

import software.amazon.awscdk.pipelines.CodePipeline
import software.amazon.awscdk.services.cloudwatch.{Alarm, Metric}
import software.amazon.awscdk.services.codebuild.{BuildEnvironmentVariable, BuildEnvironmentVariableType}
import software.amazon.awscdk.services.codecommit.Repository
import software.amazon.awscdk.services.codepipeline.{IAction, StageProps}
import software.amazon.awscdk.services.ec2.{IVpc, SecurityGroup, Vpc}
import software.amazon.awscdk.services.elasticbeanstalk.CfnConfigurationTemplate.ConfigurationOptionSettingProperty
import software.amazon.awscdk.services.iam.*
import software.amazon.awscdk.services.rds.{CfnDBInstance, CfnDBSubnetGroup}
import software.amazon.awscdk.services.sns.Topic
import software.amazon.awscdk.services.ssm.StringParameter
import software.amazon.awscdk.{CfnOutput, CfnTag, Stack}
import software.amazon.jsii.Builder as CfnBuilder
import software.constructs.Construct

import java.util
import scala.jdk.CollectionConverters.{MapHasAsJava, SeqHasAsJava}

trait CDKSimpleSyntax:
  def principal(service: String) =
    ServicePrincipal.Builder.create(service).build()
  object principals:
    val amplify = principal("amplify.amazonaws.com")
    val lambda = principal("lambda.amazonaws.com")
  object policies:
    val basicLambda =
      ManagedPolicy.fromAwsManagedPolicyName("service-role/AWSLambdaBasicExecutionRole")
  protected def allowStatement(
    action: String,
    resource: String,
    moreResources: String*
  ): PolicyStatement = policyStatement: b =>
    b.actions(list(action))
      .effect(Effect.ALLOW)
      .resources(list(resource +: moreResources*))
  def list[T](xs: T*) = xs.asJava
  def map[T](kvs: (String, T)*): util.Map[String, T] = Map(kvs*).asJava
  def tagList(kvs: (String, String)*): util.List[CfnTag] =
    kvs
      .map:
        case (k, v) => CfnTag.builder().key(k).value(v).build()
      .asJava
  def resolveJson(secretName: String, secretKey: String) =
    s"{{resolve:secretsmanager:$secretName::$secretKey}}"
  def policyStatement(f: PolicyStatement.Builder => PolicyStatement.Builder) =
    init(PolicyStatement.Builder.create()): b =>
      f(b)
  def policyDocument(f: PolicyDocument.Builder => PolicyDocument.Builder) =
    init(PolicyDocument.Builder.create())(f)
  def optionSetting(namespace: String, optionName: String, value: String) =
    init(ConfigurationOptionSettingProperty.builder()): b =>
      b.namespace(namespace).optionName(optionName).value(value)
  def buildEnv(value: String) =
    init(BuildEnvironmentVariable.builder()): b =>
      b.`type`(BuildEnvironmentVariableType.PLAINTEXT).value(value)
  def stage(name: String)(actions: IAction*) =
    init(StageProps.builder()): b =>
      b.stageName(name).actions(list(actions*))
  def metric(f: Metric.Builder => Metric.Builder) = init(Metric.Builder.create())(f)
  def outputs(scope: Stack, exportStackName: Boolean = true)(
    kvs: (String, String)*
  ) =
    kvs.map:
      case (k, v) =>
        val exportName =
          if exportStackName then s"${scope.getStackName}-$k" else k
        init(CfnOutput.Builder.create(scope, k)): b =>
          b.exportName(exportName)
            .value(v)
  protected def init[T, B <: CfnBuilder[T]](b: B)(f: B => B): T = f(b).build()

trait CDKAdvancedSyntax extends CDKSimpleSyntax:
  def construct: Construct
  def role(id: String)(f: Role.Builder => Role.Builder) =
    init(Role.Builder.create(construct, id))(f)
  def buildVpc(id: String)(f: Vpc.Builder => Vpc.Builder) =
    init(Vpc.Builder.create(construct, id))(f)
  def secGroup(id: String, vpc: IVpc)(
    f: SecurityGroup.Builder => SecurityGroup.Builder
  ) =
    init(SecurityGroup.Builder.create(construct, id)): b =>
      f(b.vpc(vpc))
  def topic(id: String)(f: Topic.Builder => Topic.Builder) =
    init(Topic.Builder.create(construct, id)): b =>
      f(b)
  def dbInstance(id: String)(
    f: CfnDBInstance.Builder => CfnDBInstance.Builder
  ) =
    init(CfnDBInstance.Builder.create(construct, id))(f)
  def dbSubnetGroup(id: String)(
    f: CfnDBSubnetGroup.Builder => CfnDBSubnetGroup.Builder
  ) =
    init(CfnDBSubnetGroup.Builder.create(construct, id)): b =>
      f(b)
  def codeCommitRepo(id: String)(f: Repository.Builder => Repository.Builder) =
    init(Repository.Builder.create(construct, id))(f)
  def codePipeline(construct: Construct, id: String)(
    prep: CodePipeline.Builder => CodePipeline.Builder
  ) =
    init[CodePipeline, CodePipeline.Builder](CodePipeline.Builder.create(construct, id))(prep)
  def stringParameter(name: String) = StringParameter.valueFromLookup(construct, name)
  def alarm(id: String)(f: Alarm.Builder => Alarm.Builder) =
    init(Alarm.Builder.create(construct, id))(f)
