package com.malliina.cdk

import software.amazon.awscdk.pipelines.CodePipeline
import software.amazon.awscdk.services.codebuild.{BuildEnvironmentVariable, BuildEnvironmentVariableType}
import software.amazon.awscdk.services.codecommit.Repository
import software.amazon.awscdk.services.codepipeline.{IAction, StageProps}
import software.amazon.awscdk.services.iam.ServicePrincipal
import software.amazon.awscdk.{CfnOutput, Stack}
import software.amazon.jsii.Builder as CfnBuilder
import software.constructs.Construct

import scala.jdk.CollectionConverters.{MapHasAsJava, SeqHasAsJava}

trait CDKSyntax:
  def principal(service: String) = ServicePrincipal.Builder.create(service).build()
  def list[T](xs: T*) = xs.asJava
  def map[T](kvs: (String, T)*) = Map(kvs*).asJava
  def outputs(scope: Stack)(kvs: (String, String)*) = kvs.map:
    case (k, v) =>
      CfnOutput.Builder
        .create(scope, k)
        .exportName(k)
        .value(v)
        .build()

  def buildEnv(value: String) =
    BuildEnvironmentVariable
      .builder()
      .`type`(BuildEnvironmentVariableType.PLAINTEXT)
      .value(value)
      .build()

  def stage(name: String)(actions: IAction*) =
    StageProps
      .builder()
      .stageName(name)
      .actions(list(actions*))
      .build()

  def codeCommit(construct: Construct, id: String)(prep: Repository.Builder => Repository.Builder) =
    prep(Repository.Builder.create(construct, id)).build()

  def codePipeline(construct: Construct, id: String)(
    prep: CodePipeline.Builder => CodePipeline.Builder
  ) =
    init[CodePipeline, CodePipeline.Builder](CodePipeline.Builder.create(construct, id))(prep)

  private def init[T, B <: CfnBuilder[T]](b: B)(f: B => B): T = f(b).build()
