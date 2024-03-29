val cdk = project
  .in(file("."))
  .settings(
    version := "0.0.1",
    scalaVersion := "3.3.0",
    crossScalaVersions := Seq(scalaVersion.value),
    libraryDependencies ++= Seq(
      "software.amazon.awscdk" % "aws-cdk-lib" % "2.96.2",
      "org.scalameta" %% "munit" % "0.7.29" % Test
    ),
    testFrameworks += new TestFramework("munit.Framework")
  )
