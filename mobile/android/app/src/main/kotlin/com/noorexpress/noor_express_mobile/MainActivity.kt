package com.noorexpress.noor_express_mobile

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_LOCATION_CHANNEL,
        ).setMethodCallHandler(::handleForegroundLocationCall)
    }

    private fun handleForegroundLocationCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_START -> startDriverForegroundService(call, result)
            METHOD_STOP -> stopDriverForegroundService(result)
            METHOD_IS_RUNNING -> result.success(
                DriverForegroundLocationService.isRunning,
            )
            else -> result.notImplemented()
        }
    }

    private fun startDriverForegroundService(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val title = call.argument<String>(ARGUMENT_TITLE) ?: DEFAULT_TITLE
        val body = call.argument<String>(ARGUMENT_BODY) ?: DEFAULT_BODY
        val intent = DriverForegroundLocationService.startIntent(
            context = this,
            title = title,
            body = body,
        )
        runCatching { launchForegroundService(intent) }
            .onSuccess { result.success(null) }
            .onFailure { error ->
                result.error(ERROR_FOREGROUND_LOCATION, error.message, null)
            }
    }

    private fun stopDriverForegroundService(result: MethodChannel.Result) {
        stopService(Intent(this, DriverForegroundLocationService::class.java))
        result.success(null)
    }

    private fun launchForegroundService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
            return
        }
        startService(intent)
    }

    companion object {
        private const val FOREGROUND_LOCATION_CHANNEL =
            "noor_express/foreground_location"
        private const val METHOD_START = "start"
        private const val METHOD_STOP = "stop"
        private const val METHOD_IS_RUNNING = "isRunning"
        private const val ARGUMENT_TITLE = "title"
        private const val ARGUMENT_BODY = "body"
        private const val DEFAULT_TITLE = "Noor Express actif"
        private const val DEFAULT_BODY =
            "Votre position chauffeur est partagee pendant la course."
        private const val ERROR_FOREGROUND_LOCATION = "foreground_location_error"
    }
}
