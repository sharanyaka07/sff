package com.example.safe_connect

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelUuid
import android.os.PowerManager
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID

// ════════════════════════════════════════════════════════════════
// BLE Foreground Service — keeps BLE alive when screen is off
// ════════════════════════════════════════════════════════════════
class BleService : Service() {

    private val CHANNEL_ID = "safe_connect_ble"
    private val NOTIF_ID   = 1001

    inner class LocalBinder : Binder() {
        fun getService(): BleService = this@BleService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = buildNotification()
        startForeground(NOTIF_ID, notification)
        Log.d("BleService", "Foreground service started ✅")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("BleService", "Foreground service stopped")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Safe Connect Bluetooth",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Bluetooth connection active"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Safe Connect")
            .setContentText("Bluetooth connection active")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}

// ════════════════════════════════════════════════════════════════
// MainActivity
// ════════════════════════════════════════════════════════════════
class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL     = "com.safeconnect.sms/send"
    private val GATT_CHANNEL    = "com.safeconnect.gatt/server"
    private val MESSAGE_CHANNEL = "com.safeconnect.gatt/messages"

    private val SERVICE_UUID = UUID.fromString("12345678-1234-1234-1234-123456789abc")
    private val CHAR_UUID    = UUID.fromString("abcd1234-1234-1234-1234-abcdef123456")

    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private val connectedCentrals = mutableListOf<BluetoothDevice>()

    private var wakeLock: PowerManager.WakeLock? = null

    private val deviceNameCache = mutableMapOf<String, String>()

    private val chunkBuffers   = mutableMapOf<String, StringBuilder>()
    private val expectedChunks = mutableMapOf<String, Int>()
    private val receivedChunks = mutableMapOf<String, Int>()

    private val pendingConnectDevices      = mutableMapOf<String, BluetoothDevice>()
    private val handshakeTimeoutHandlers   = mutableMapOf<String, Runnable>()
    private val mainHandler                = Handler(Looper.getMainLooper())
    private val HANDSHAKE_TIMEOUT_MS       = 5000L

    private var messageSink: EventChannel.EventSink? = null
    private var isServerRunning = false
    private var nameScanner: BluetoothLeScanner? = null

    // ─────────────────────────────────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupSmsChannel(flutterEngine)
        setupGattChannel(flutterEngine)
        setupMessageEventChannel(flutterEngine)
    }

    @SuppressLint("MissingPermission")
    override fun onStart() {
        super.onStart()
        acquireWakeLock()
        startBleService()
        if (!isServerRunning) {
            try {
                startGattServer()
                startAdvertising()
                startNameScan()
                isServerRunning = true
                Log.d("GATT", "Auto-started GATT server ✅")
            } catch (e: Exception) {
                Log.e("GATT", "Auto-start failed: ${e.message}")
            }
        }
    }

    private fun startBleService() {
        try {
            val intent = Intent(this, BleService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d("GATT", "BLE foreground service started ✅")
        } catch (e: Exception) {
            Log.e("GATT", "Failed to start BLE service: ${e.message}")
        }
    }

    private fun stopBleService() {
        try {
            stopService(Intent(this, BleService::class.java))
        } catch (e: Exception) {
            Log.e("GATT", "Failed to stop BLE service: ${e.message}")
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "SafeConnect::BluetoothWakeLock"
                )
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(60 * 60 * 1000L)
                Log.d("GATT", "Wake lock acquired ✅")
            }
        } catch (e: Exception) {
            Log.e("GATT", "Wake lock failed: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d("GATT", "Wake lock released")
            }
        } catch (e: Exception) {
            Log.e("GATT", "Wake lock release failed: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun startNameScan() {
        try {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            nameScanner = bm.adapter.bluetoothLeScanner

            val cb = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val address = result.device.address
                    val name = result.scanRecord?.deviceName ?: result.device.name ?: return
                    if (name.isNotEmpty()) {
                        deviceNameCache[address] = name
                    }
                }
            }

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                .build()

            nameScanner?.startScan(null, settings, cb)
        } catch (e: Exception) {
            Log.e("GATT", "Name scan failed: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun getDeviceName(device: BluetoothDevice): String {
        val cached = deviceNameCache[device.address]
        if (!cached.isNullOrEmpty()) return cached
        val name = try { device.name } catch (e: Exception) { null }
        if (!name.isNullOrEmpty()) return name
        return device.address
    }

    private fun scheduleClientConnectedWithHandshakeWait(device: BluetoothDevice) {
        val addr = device.address
        handshakeTimeoutHandlers[addr]?.let { mainHandler.removeCallbacks(it) }
        pendingConnectDevices[addr] = device

        val timeout = Runnable {
            if (pendingConnectDevices.containsKey(addr)) {
                pendingConnectDevices.remove(addr)
                handshakeTimeoutHandlers.remove(addr)
                val name = getDeviceName(device)
                Log.d("GATT", "Handshake timeout — fallback name: $name")
                messageSink?.success("CLIENT_CONNECTED:$name")
            }
        }
        handshakeTimeoutHandlers[addr] = timeout
        mainHandler.postDelayed(timeout, HANDSHAKE_TIMEOUT_MS)
    }

    private fun handleFullMessage(addr: String, payload: String) {
        try {
            val json = JSONObject(payload)
            if (json.optString("type") == "handshake") {
                val senderName = json.optString("senderName", "")
                if (senderName.isNotEmpty()) {
                    deviceNameCache[addr] = senderName
                    if (pendingConnectDevices.containsKey(addr)) {
                        handshakeTimeoutHandlers[addr]?.let { mainHandler.removeCallbacks(it) }
                        pendingConnectDevices.remove(addr)
                        handshakeTimeoutHandlers.remove(addr)
                        runOnUiThread { messageSink?.success("CLIENT_CONNECTED:$senderName") }
                    } else {
                        runOnUiThread { messageSink?.success("CLIENT_NAME_UPDATE:$addr:$senderName") }
                    }
                }
                runOnUiThread { messageSink?.success(payload) }
                return
            }
        } catch (e: Exception) { /* not JSON */ }
        runOnUiThread { messageSink?.success(payload) }
    }

    // ════════════════════════════════════════════════════════════════
    // SMS Channel
    // ════════════════════════════════════════════════════════════════
    private fun setupSmsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message     = call.argument<String>("message")
                        if (phoneNumber == null || message == null) {
                            result.error("INVALID_ARGS", "Phone or message is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val smsManager: SmsManager =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                                    applicationContext.getSystemService(SmsManager::class.java)
                                else @Suppress("DEPRECATION") SmsManager.getDefault()
                            val parts = smsManager.divideMessage(message)
                            if (parts.size == 1)
                                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                            else
                                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ════════════════════════════════════════════════════════════════
    // GATT Method Channel
    // ════════════════════════════════════════════════════════════════
    @SuppressLint("MissingPermission")
    private fun setupGattChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GATT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startGattServer" -> {
                        try {
                            acquireWakeLock()
                            startBleService()
                            if (!isServerRunning) {
                                startGattServer()
                                startAdvertising()
                                startNameScan()
                                isServerRunning = true
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("GATT_ERROR", e.message, null)
                        }
                    }
                    "stopGattServer" -> {
                        stopGattServer()
                        releaseWakeLock()
                        stopBleService()
                        isServerRunning = false
                        result.success(true)
                    }
                    "sendMessage" -> {
                        val payload = call.argument<String>("payload")
                        if (payload == null) {
                            result.error("INVALID_ARGS", "Payload is null", null)
                            return@setMethodCallHandler
                        }
                        result.success(notifyAllCentrals(payload))
                    }
                    // ── FIXED: update BLE advertised name when user changes name ──
                    "updateDeviceName" -> {
                        val name = call.argument<String>("name") ?: ""
                        if (name.isNotEmpty()) {
                            try {
                                val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                                bm.adapter.name = name
                                Log.d("GATT", "Device name updated to: $name")
                                // Restart advertising so new name is broadcast immediately
                                advertiser?.stopAdvertising(advertiseCallback)
                                startAdvertising()
                            } catch (e: Exception) {
                                Log.e("GATT", "Failed to update name: ${e.message}")
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ════════════════════════════════════════════════════════════════
    // EventChannel
    // ════════════════════════════════════════════════════════════════
    private fun setupMessageEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESSAGE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    messageSink = sink
                    Log.d("GATT", "Flutter listening ✅")
                }
                override fun onCancel(arguments: Any?) { messageSink = null }
            })
    }

    // ════════════════════════════════════════════════════════════════
    // GATT Server
    // ════════════════════════════════════════════════════════════════
    @SuppressLint("MissingPermission")
    private fun startGattServer() {
        gattServer?.close()
        gattServer = null
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        gattServer = bm.openGattServer(this, gattServerCallback)

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val char = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
            BluetoothGattCharacteristic.PROPERTY_WRITE or
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val descriptor = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        char.addDescriptor(descriptor)
        service.addCharacteristic(char)
        gattServer?.addService(service)
        Log.d("GATT", "GATT server started ✅")
    }

    @SuppressLint("MissingPermission")
    private fun stopGattServer() {
        advertiser?.stopAdvertising(advertiseCallback)
        gattServer?.close()
        gattServer = null
        connectedCentrals.clear()
        pendingConnectDevices.clear()
        handshakeTimeoutHandlers.values.forEach { mainHandler.removeCallbacks(it) }
        handshakeTimeoutHandlers.clear()
        isServerRunning = false
        Log.d("GATT", "GATT server stopped")
    }

    @SuppressLint("MissingPermission")
    private val gattServerCallback = object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (!connectedCentrals.contains(device)) connectedCentrals.add(device)
                acquireWakeLock()
                Log.d("GATT", "Central connected: ${device.address}")
                runOnUiThread { scheduleClientConnectedWithHandshakeWait(device) }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                val addr = device.address
                connectedCentrals.remove(device)
                chunkBuffers.remove(addr)
                expectedChunks.remove(addr)
                receivedChunks.remove(addr)
                handshakeTimeoutHandlers[addr]?.let { mainHandler.removeCallbacks(it) }
                pendingConnectDevices.remove(addr)
                handshakeTimeoutHandlers.remove(addr)
                Log.d("GATT", "Central disconnected: $addr")
                runOnUiThread {
                    if (connectedCentrals.isEmpty()) messageSink?.success("CLIENT_DISCONNECTED")
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice, requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean,
            offset: Int, value: ByteArray
        ) {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            if (value.size < 3) return

            val chunkIndex  = value[0].toInt() and 0xFF
            val totalChunks = value[1].toInt() and 0xFF
            val chunkData   = value.copyOfRange(2, value.size)
            val addr = device.address

            if (chunkIndex == 0) {
                chunkBuffers[addr]   = StringBuilder()
                expectedChunks[addr] = totalChunks
                receivedChunks[addr] = 0
            }

            chunkBuffers[addr]?.append(String(chunkData, Charsets.UTF_8))
            receivedChunks[addr] = (receivedChunks[addr] ?: 0) + 1

            if (receivedChunks[addr] == expectedChunks[addr]) {
                val full = chunkBuffers[addr].toString()
                chunkBuffers.remove(addr)
                expectedChunks.remove(addr)
                receivedChunks.remove(addr)
                handleFullMessage(addr, full)
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice, requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean,
            offset: Int, value: ByteArray
        ) {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice, requestId: Int,
            offset: Int, characteristic: BluetoothGattCharacteristic
        ) {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0,
                "SafeConnect".toByteArray())
        }
    }

    @SuppressLint("MissingPermission")
    private fun notifyAllCentrals(payload: String): Boolean {
        val server  = gattServer ?: return false
        val service = server.getService(SERVICE_UUID) ?: return false
        val char    = service.getCharacteristic(CHAR_UUID) ?: return false
        if (connectedCentrals.isEmpty()) return false

        val bytes       = payload.toByteArray(Charsets.UTF_8)
        val chunkSize   = 180
        val totalChunks = Math.ceil(bytes.size.toDouble() / chunkSize).toInt()

        for (i in 0 until totalChunks) {
            val start  = i * chunkSize
            val end    = minOf(start + chunkSize, bytes.size)
            val chunk  = bytes.copyOfRange(start, end)
            val packet = ByteArray(chunk.size + 2)
            packet[0]  = i.toByte()
            packet[1]  = totalChunks.toByte()
            chunk.copyInto(packet, 2)
            char.value = packet
            for (device in connectedCentrals) {
                server.notifyCharacteristicChanged(device, char, false)
            }
            Thread.sleep(30)
        }
        Log.d("GATT", "Notified ${connectedCentrals.size} centrals ✅")
        return true
    }

    // ════════════════════════════════════════════════════════════════
    // Advertising — FIXED: device name in scan response packet
    // so it never gets truncated due to 31-byte advertisement limit
    // ════════════════════════════════════════════════════════════════
    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        advertiser = bm.adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e("GATT", "BLE advertising not supported!")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        // ── Primary advertisement packet (31 bytes max) ──────────
        // Only service UUID here — no device name to avoid overflow
        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()

        // ── Scan response packet (extra 31 bytes) ────────────────
        // Device name goes here so it is never truncated or dropped
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(false)
            .build()

        advertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
        Log.d("GATT", "Advertising started with scan response ✅")
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.d("GATT", "Advertising SUCCESS ✅")
        }
        override fun onStartFailure(errorCode: Int) {
            Log.e("GATT", "Advertising FAILED: $errorCode")
        }
    }

    @SuppressLint("MissingPermission")
    override fun onDestroy() {
        stopGattServer()
        releaseWakeLock()
        stopBleService()
        super.onDestroy()
    }
}