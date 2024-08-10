package com.malliina.aws

import com.amazonaws.services.lambda.runtime.events.CloudWatchLogsEvent
import com.amazonaws.services.lambda.runtime.{Context, RequestHandler}

import java.time.Instant

class CloudWatchHandler extends RequestHandler[CloudWatchLogsEvent, String]:
  override def handleRequest(event: CloudWatchLogsEvent, context: Context): String =
    val now = Instant.now()
    val zipped = event.getAwsLogs.getData
    val eventData = EventData.fromCloudWatchEvent(event)
    println(s"Hello, Lambda! The time is now $now.")
    s"Handled event '$zipped'."
