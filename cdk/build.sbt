inThisBuild(
  Seq(
    version := "0.0.1",
    organization := "com.malliina",
    scalaVersion := "3.4.2",
    Test / publishArtifact := true,
    libraryDependencies += "org.scalameta" %% "munit" % "1.0.0" % Test
  )
)

val cdkVersion = "2.150.0"

val cdk = project
  .in(file("cdk"))
  .enablePlugins(BuildInfoPlugin)
  .settings(
    libraryDependencies ++= Seq(
      "software.amazon.awscdk" % "aws-cdk-lib" % cdkVersion
    ),
    buildInfoPackage := "com.malliina.cdk",
    buildInfoKeys ++= Seq[BuildInfoKey](
      "cdkVersion" -> cdkVersion
    )
  )

val lambda = project
  .in(file("lambda"))
  .settings(
    libraryDependencies ++= Seq(
      "ch.qos.logback" % "logback-classic" % "1.5.6",
      "com.malliina" %% "primitives" % "3.7.3",
      "com.amazonaws" % "aws-lambda-java-core" % "1.2.3",
      "com.amazonaws" % "aws-lambda-java-events" % "3.13.0"
    ),
    assembly / assemblyMergeStrategy := {
      case PathList("module-info.class")                              => MergeStrategy.first
      case PathList("META-INF", "versions", "9", "module-info.class") => MergeStrategy.last
      case PathList("META-INF", xs @ _*)                              => MergeStrategy.first
      case x =>
        val oldStrategy = (ThisBuild / assemblyMergeStrategy).value
        oldStrategy(x)
    }
  )

val root = project
  .in(file("."))
  .aggregate(cdk, lambda)

Global / onChangedBuildSource := ReloadOnSourceChanges
