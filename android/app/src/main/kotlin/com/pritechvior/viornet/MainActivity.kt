package com.pritechvior.viornet

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val SMS_CHANNEL = "com.lwenatech.sms_gateway/sms"
        private const val SMS_SENT = "SMS_SENT"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    if (phoneNumber != null && message != null) {
                        sendSms(phoneNumber, message, result)
                    } else {
                        result.error("INVALID_ARGS", "phoneNumber or message is null", null)
                    }
                }
                "sendBulkSms" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                    val message = call.argument<String>("message")
                    if (phoneNumbers != null && message != null) {
                        sendBulkSms(phoneNumbers, message, result)
                    } else {
                        result.error("INVALID_ARGS", "phoneNumbers or message is null", null)
                    }
                }
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.SEND_SMS),
                        1001
                    )
                    result.success(true)
                }
                "getSimCards" -> {
                    getSimCards(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─── Send single SMS via SmsManager ───────────────────────────────────

    private fun sendSms(phoneNumber: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
            return
        }
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val sentPI = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getBroadcast(
                    this, 0, Intent(SMS_SENT),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                @Suppress("UnspecifiedImmutableFlag")
                PendingIntent.getBroadcast(
                    this, 0, Intent(SMS_SENT),
                    PendingIntent.FLAG_UPDATE_CURRENT
                )
            }

            // Split long messages automatically
            val parts = smsManager.divideMessage(message)
            if (parts.size == 1) {
                smsManager.sendTextMessage(phoneNumber, null, message, sentPI, null)
            } else {
                val piList = ArrayList<PendingIntent>(parts.size).apply {
                    repeat(parts.size) { add(sentPI) }
                }
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, piList, null)
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }

    // ─── Send bulk SMS ─────────────────────────────────────────────────────

    private fun sendBulkSms(
        phoneNumbers: List<String>,
        message: String,
        result: MethodChannel.Result
    ) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
            return
        }
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            var sentCount = 0
            val failed = mutableListOf<String>()

            for (phone in phoneNumbers) {
                try {
                    val sentPI = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.getBroadcast(
                            this, phone.hashCode(),
                            Intent(SMS_SENT).putExtra("phone", phone),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                    } else {
                        @Suppress("UnspecifiedImmutableFlag")
                        PendingIntent.getBroadcast(
                            this, phone.hashCode(),
                            Intent(SMS_SENT).putExtra("phone", phone),
                            PendingIntent.FLAG_UPDATE_CURRENT
                        )
                    }
                    val parts = smsManager.divideMessage(message)
                    if (parts.size == 1) {
                        smsManager.sendTextMessage(phone, null, message, sentPI, null)
                    } else {
                        val piList = ArrayList<PendingIntent>(parts.size).apply {
                            repeat(parts.size) { add(sentPI) }
                        }
                        smsManager.sendMultipartTextMessage(phone, null, parts, piList, null)
                    }
                    sentCount++
                } catch (e: Exception) {
                    failed.add(phone)
                }
            }

            result.success(
                mapOf("successCount" to sentCount, "failedNumbers" to failed)
            )
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }

    // ─── SIM card detection ────────────────────────────────────────────────

    private fun getSimCards(result: MethodChannel.Result) {
        val simList = mutableListOf<Map<String, Any?>>()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 &&
                ContextCompat.checkSelfPermission(
                    this, Manifest.permission.READ_PHONE_STATE
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                val subManager =
                    getSystemService(SubscriptionManager::class.java)
                val subs = subManager?.activeSubscriptionInfoList

                if (!subs.isNullOrEmpty()) {
                    for (sub in subs) {
                        simList.add(
                            mapOf(
                                "slotId" to sub.simSlotIndex,
                                "subscriptionId" to sub.subscriptionId,
                                "displayName" to (sub.displayName?.toString()
                                    ?: "SIM ${sub.simSlotIndex + 1}"),
                                "carrierName" to (sub.carrierName?.toString() ?: ""),
                                "countryIso" to sub.countryIso,
                                "phoneNumber" to (sub.number ?: ""),
                            )
                        )
                    }
                }
            }
        } catch (_: Exception) {}

        // Always return at least SIM 1 as fallback
        if (simList.isEmpty()) {
            simList.add(
                mapOf(
                    "slotId" to 0,
                    "subscriptionId" to -1,
                    "displayName" to "SIM 1",
                    "carrierName" to "",
                    "countryIso" to "",
                    "phoneNumber" to "",
                )
            )
        }

        result.success(simList)
    }
}
