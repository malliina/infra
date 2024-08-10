package com.malliina.aws

import ch.qos.logback.classic.Level
import com.amazonaws.services.lambda.runtime.events.CloudWatchLogsEvent
import io.circe.{Codec, Decoder, Encoder, Error, parser}

import java.io.{ByteArrayInputStream, ByteArrayOutputStream}
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.zip.GZIPInputStream

enum MessageType(val name: String):
  case DataMessage extends MessageType("DATA_MESSAGE")
  case Other(n: String) extends MessageType(n)

object MessageType:
  given Codec[MessageType] = Codec.from(
    Decoder.decodeString.map(s => Seq(DataMessage).find(_.name == s).getOrElse(Other(s))),
    Encoder.encodeString.contramap(_.name)
  )

given Codec[Level] = Codec.from(
  Decoder.decodeString.map(s => Level.toLevel(s)),
  Encoder.encodeString.contramap(l => l.levelStr)
)

case class ExtractedFields(
  level: Option[Level],
  message: Option[String],
  timestamp: Option[String],
  logger: Option[String],
  thread: Option[String]
) derives Codec.AsObject:
  def require = for
    lvl <- level
    m <- message
    lgr <- logger
    t <- thread
  yield RequiredFields(lvl, m, lgr, t)

case class RequiredFields(
  level: Level,
  message: String,
  logger: String,
  thread: String
)

/** @param id
  *   some AWS id
  * @param timestamp
  *   e.g. 1722792519455
  * @param message
  *   as logged by the app
  * @param extractedFields
  *   a map of fields extracted if you use a space delimited format in the subscription
  */
case class CWLogEvent(
  id: String,
  timestamp: Long,
  message: String,
  extractedFields: Option[ExtractedFields]
) derives Codec.AsObject

case class EventData(
  messageType: MessageType,
  owner: String,
  logGroup: String,
  logStream: String,
  subscriptionFilters: Seq[String],
  logEvents: Seq[CWLogEvent]
) derives Codec.AsObject

object EventData:
  def fromCloudWatchEvent(e: CloudWatchLogsEvent): Either[Error, EventData] =
    fromCloudWatchData(e.getAwsLogs.getData)

  def fromCloudWatchData(data: String): Either[Error, EventData] =
    val zipped = Base64.getDecoder.decode(data)
    val unzipped = unzip(zipped)
    val str = new String(unzipped, StandardCharsets.UTF_8)
    parser.decode[EventData](str)

  private def unzip(zipped: Array[Byte]): Array[Byte] =
    using(ByteArrayInputStream(zipped)): baIn =>
      using(GZIPInputStream(baIn)): gzIn =>
        val out = ByteArrayOutputStream()
        gzIn.transferTo(out)
        out.toByteArray

  private def using[R <: AutoCloseable, T](res: R)(code: R => T): T =
    try code(res)
    finally res.close()
