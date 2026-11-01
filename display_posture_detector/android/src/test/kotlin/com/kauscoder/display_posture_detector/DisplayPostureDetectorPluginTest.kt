package com.kauscoder.display_posture_detector

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class DisplayPostureDetectorPluginTest {
    @Test
    fun onMethodCall_unknownMethod_callsNotImplemented() {
        val plugin = DisplayPostureDetectorPlugin()

        val call = MethodCall("unknownMethod", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun onMethodCall_getMetrics_withoutActivity_returnsError() {
        val plugin = DisplayPostureDetectorPlugin()

        val call = MethodCall("getMetrics", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("NO_ACTIVITY"),
            Mockito.eq("Activity is not attached"),
            Mockito.isNull()
        )
    }
}
