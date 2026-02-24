package com.pritechvior.viornet

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ViornetSMS"
        private const val SMS_CHANNEL = "com.lwenatech.sms_gateway/sms"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    // ─── Flutter engine setup ─────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message     = call.argument<String>("message")
                    val subId       = call.argument<Int>("subscriptionId") ?: -1
                    if (phoneNumber != null && message != null) {
                        sendSms(phoneNumber, message, subId, result)
                    } else {
                        result.error("INVALID_ARGS", "phoneNumber or message is null", null)
                    }
                }
                "sendBulkSms" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                    val message      = call.argument<String>("message")
                    val subId        = call.argument<Int>("subscriptionId") ?: -1
                    if (phoneNumbers != null && message != null) {
                        sendBulkSms(phoneNumbers, message, subId, result)
                    } else {
                        result.error("INVALID_ARGS", "phoneNumbers or message is null", null)
                    }
                }
                "checkSmsPermission" -> result.success(hasSmsPermission())
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.SEND_SMS,
                            Manifest.permission.READ_PHONE_STATE
                        ),
                        PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                }
                "getSimCards" -> getSimCards(result)
                else -> result.notImplemented()
            }
        }
    }

    // ─── Permission helper ────────────────────────────────────────────────

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
                PackageManager.PERMISSION_GRANTED

    // ─── Pick the right SmsManager (key for multi-SIM phones) ─────────────
    //
    // When subscriptionId >= 0 we target that specific SIM card.
    // -1 means "system default SIM".

    @Suppress("DEPRECATION")
    private fun getSmsManager(subscriptionId: Int): SmsManager {
        return if (subscriptionId >= 0 &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1
        ) {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    // ─── Build a unique PendingIntent per send ────────────────────────────

    private fun makeSentIntent(tag: String, phone: String): PendingIntent {
        val action  = "com.pritechvior.viornet.SMS_SENT_$tag"
        val intent  = Intent(action).putExtra("phone", phone)
        val flags   = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            @Suppress("UnspecifiedImmutableFlag")
            PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(this, phone.hashCode(), intent, flags)
    }

    // ─── Send single SMS ──────────────────────────────────────────────────
    //
    // We register a one-shot BroadcastReceiver, kick off the send, then
    // wait for the SMS_SENT broadcast on a background thread so we never
    // block the main/UI thread (which would cause an ANR).

    private fun sendSms(
        phoneNumber: String,
        message: String,
        subscriptionId: Int,
        result: MethodChannel.Result
    ) {
        if (!hasSmsPermission()) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
            return
        }

        Thread {
            try {
                val smsManager = getSmsManager(subscriptionId)
                val tag        = System.currentTimeMillis().toString()
                val action     = "com.pritechvior.viornet.SMS_SENT_$tag"
                val sentPI     = makeSentIntent(tag, phoneNumber)

                // Capture the sent result via a one-shot receiver.
                val resultHolder = arrayOf(true)  // optimistic
                val done         = java.util.concurrent.CountDownLatch(1)

                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(ctx: Context?, intent: Intent?) {
                        resultHolder[0] = (resultCode == android.app.Activity.RESULT_OK)
                        Log.d(TAG, "SMS_SENT broadcast: resultCode=$resultCode phone=$phoneNumber")
                        done.countDown()
                    }
                }

                val filter = IntentFilter(action)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(receiver, filter)
                }

                try {
                    val parts = smsManager.divideMessage(message)
                    if (parts.size == 1) {
                        smsManager.sendTextMessage(phoneNumber, null, message, sentPI, null)
                    } else {
                        val piList = ArrayList<PendingIntent?>(parts.size)
                        piList.add(sentPI)
                        for (i in 1 until parts.size) piList.add(null)
                        @Suppress("UNCHECKED_CAST")
                        smsManager.sendMultipartTextMessage(
                            phoneNumber, null, parts,
                            piList as ArrayList<PendingIntent>, null
                        )
                    }
                    Log.i(TAG, "sendTextMessage dispatched → $phoneNumber (subId=$subscriptionId)")

                    // Wait up to 20 s; on timeout treat as success (message was
                    // handed to the modem; carrier may just be slow).
                    if (!done.await(20, java.util.concurrent.TimeUnit.SECONDS)) {
                        Log.w(TAG, "SMS_SENT broadcast timed out for $phoneNumber")
                    }
                } finally {
                    try { unregisterReceiver(receiver) } catch (_: Exception) {}
                }

                // Return on main thread as required by Flutter MethodChannel.
                Handler(Looper.getMainLooper()).post {
                    result.success(resultHolder[0])
                }

            } catch (e: Exception) {
                Log.e(TAG, "sendSms error: ${e.message}", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("SEND_ERROR", e.message ?: e.javaClass.simpleName, null)
                }
            }
        }.start()
    }

    // ─── Send bulk SMS ────────────────────────────────────────────────────

    private fun sendBulkSms(
        phoneNumbers: List<String>,
        message: String,
        subscriptionId: Int,
        result: MethodChannel.Result
    ) {
        if (!hasSmsPermission()) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
            return
        }

        Thread {
            try {
                val smsManager = getSmsManager(subscriptionId)
                var sentCount  = 0
                val failed     = mutableListOf<String>()

                for (phone in phoneNumbers) {
                    try {
                        val tag    = "${System.currentTimeMillis()}_${phone.hashCode()}"
                        val sentPI = makeSentIntent(tag, phone)

                        val parts = smsManager.divideMessage(message)
                        if (parts.size == 1) {
                            smsManager.sendTextMessage(phone, null, message, sentPI, null)
                        } else {
                            val piList = ArrayList<PendingIntent?>(parts.size)
                            piList.add(sentPI)
                            for (i in 1 until parts.size) piList.add(null)
                            @Suppress("UNCHECKED_CAST")
                            smsManager.sendMultipartTextMessage(
                                phone, null, parts,
                                piList as ArrayList<PendingIntent>, null
                            )
                        }
                        sentCount++
                        Log.i(TAG, "Bulk SMS dispatched → $phone (subId=$subscriptionId)")

                        // Small delay between sends to avoid modem overload.
                        Thread.sleep(300)
                    } catch (e: Exception) {
                        Log.e(TAG, "Bulk send failed for $phone: ${e.message}")
                        failed.add(phone)
                    }
                }

                val resultMap = mapOf(
                    "successCount" to sentCount,
                    "failedNumbers" to failed
                )
                Handler(Looper.getMainLooper()).post {
                    result.success(resultMap)
                }

            } catch (e: Exception) {
                Log.e(TAG, "sendBulkSms error: ${e.message}", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("SEND_ERROR", e.message ?: e.javaClass.simpleName, null)
                }
            }
        }.start()
    }

    // ─── SIM card detection ───────────────────────────────────────────────

    private fun getSimCards(result: MethodChannel.Result) {
        val simList = mutableListOf<Map<String, Any?>>()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 &&
                ContextCompat.checkSelfPermission(
                    this, Manifest.permission.READ_PHONE_STATE
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                val subManager = getSystemService(SubscriptionManager::class.java)
                val subs       = subManager?.activeSubscriptionInfoList

                if (!subs.isNullOrEmpty()) {
                    for (sub in subs) {
                        simList.add(
                            mapOf(
                                "slotId"         to sub.simSlotIndex,
                                "subscriptionId" to sub.subscriptionId,
                                "displayName"    to (sub.displayName?.toString()
                                    ?: "SIM ${sub.simSlotIndex + 1}"),
                                "carrierName"    to (sub.carrierName?.toString() ?: ""),
                                "countryIso"     to sub.countryIso,
                                "phoneNumber"    to (sub.number ?: ""),
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "getSimCards error: ${e.message}")
        }

        if (simList.isEmpty()) {
            simList.add(
                mapOf(
                    "slotId"         to 0,
                    "subscriptionId" to -1,
                    "displayName"    to "SIM 1",
                    "carrierName"    to "",
                    "countryIso"     to "",
                    "phoneNumber"    to "",
                )
            )
        }

        result.success(simList)
    }
}
