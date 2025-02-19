scalaVersion := "2.12.20"

Seq(
  "com.eed3si9n" % "sbt-assembly" % "2.3.1",
  "org.scalameta" % "sbt-scalafmt" % "2.5.4",
  "com.eed3si9n" % "sbt-buildinfo" % "0.13.1"
) map addSbtPlugin
