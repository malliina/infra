scalaVersion := "2.12.19"

Seq(
  "com.eed3si9n" % "sbt-assembly" % "2.2.0",
  "org.scalameta" % "sbt-scalafmt" % "2.5.2",
  "com.eed3si9n" % "sbt-buildinfo" % "0.12.0"
) map addSbtPlugin
