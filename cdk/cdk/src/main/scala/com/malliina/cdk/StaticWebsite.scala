package com.malliina.cdk

import com.malliina.cdk.StaticWebsite.StaticConf
import software.amazon.awscdk.services.cloudfront.CfnDistribution
import software.amazon.awscdk.services.cloudfront.CfnDistribution.*
import software.amazon.awscdk.services.iam.{AnyPrincipal, PolicyStatement}
import software.amazon.awscdk.services.s3.{BlockPublicAccess, Bucket}
import software.amazon.awscdk.{RemovalPolicy, Stack}
import software.constructs.Construct

object StaticWebsite:
  case class StaticConf(
    domain: String,
    certificateParamName: String
  )

class StaticWebsite(conf: StaticConf, scope: Construct, stackName: String)
  extends Stack(scope, stackName, CDK.stackProps)
  with CDKAdvancedSyntax:
  val stack = this
  override val construct: Construct = stack

  val indexDocument = "index.html"

  val headerName = "Referer"
  val secretHeader = "secret"

  val bucket = Bucket.Builder
    .create(stack, "bucket")
    .websiteIndexDocument(indexDocument)
    .websiteErrorDocument("error.html")
    .removalPolicy(RemovalPolicy.RETAIN)
    .blockPublicAccess(BlockPublicAccess.Builder.create().blockPublicPolicy(false).build())
    .build()
  bucket.addToResourcePolicy(
    PolicyStatement.Builder
      .create()
      .principals(list(new AnyPrincipal()))
      .actions(list("s3:GetObject"))
      .resources(list(s"${bucket.getBucketArn}/*"))
      .conditions(
        map("StringEquals" -> map(s"aws:$headerName" -> list(secretHeader)))
      )
      .build()
  )
  val viewerProtocolPolicy = "redirect-to-https"
  val bucketOrigin = "bucket"
  val cloudFront = CfnDistribution.Builder
    .create(stack, "cloudfront")
    .distributionConfig(
      DistributionConfigProperty
        .builder()
        .comment(s"Static website at ${conf.domain}")
        .enabled(true)
        .defaultRootObject(indexDocument)
        .aliases(list(conf.domain))
        .cacheBehaviors(
          list(
            CacheBehaviorProperty
              .builder()
              .allowedMethods(
                list("HEAD", "GET", "POST", "PUT", "PATCH", "OPTIONS", "DELETE")
              )
              .pathPattern("assets/*")
              .targetOriginId(bucketOrigin)
              .forwardedValues(
                ForwardedValuesProperty
                  .builder()
                  .queryString(true)
                  .cookies(CookiesProperty.builder().forward("none").build())
                  .build()
              )
              .viewerProtocolPolicy(viewerProtocolPolicy)
              .build()
          )
        )
        .defaultCacheBehavior(
          DefaultCacheBehaviorProperty
            .builder()
            .allowedMethods(list("HEAD", "GET"))
            .targetOriginId(bucketOrigin)
            .forwardedValues(
              ForwardedValuesProperty
                .builder()
                .queryString(true)
                .headers(list("Authorization"))
                .cookies(CookiesProperty.builder().forward("all").build())
                .build()
            )
            .viewerProtocolPolicy(viewerProtocolPolicy)
            .build()
        )
        .origins(
          list(
            OriginProperty
              .builder()
              .domainName(bucket.getBucketWebsiteDomainName)
              .id(bucketOrigin)
              .customOriginConfig(
                CustomOriginConfigProperty
                  .builder()
                  .originProtocolPolicy("http-only")
                  .build()
              )
              .originCustomHeaders(
                list(
                  OriginCustomHeaderProperty
                    .builder()
                    .headerName(headerName)
                    .headerValue(secretHeader)
                    .build()
                )
              )
              .build()
          )
        )
        .viewerCertificate(
          ViewerCertificateProperty
            .builder()
            .acmCertificateArn(stringParameter(conf.certificateParamName))
            .sslSupportMethod("sni-only")
            .build()
        )
        .build()
    )
    .build()

  val outs = outputs(stack)(
    "BucketName" -> bucket.getBucketName,
    "WebsiteURL" -> bucket.getBucketWebsiteUrl,
    "CloudFrontDomainName" -> cloudFront.getAttrDomainName
  )
