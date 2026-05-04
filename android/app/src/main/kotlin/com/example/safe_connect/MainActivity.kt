package com.example.safe_connect

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import android.telephony.SmsManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    // ── Channel names ────────────────────────────────────────────────
    private val SMS_CHANNEL     = "com.safeconnect.sms/send"
    private val GATT_CHANNEL    = "com.safeconnect.gatt/server"
    private val MESSAGE_CHANNEL = "com.safeconnect.gatt/messages"

    // ── BLE UUIDs (must match bluetooth_controller.dart) ────────────
    private val SERVICE_UUID = UUID.fromString("12345678-1234-1234-1234-123456789abc")
    private val CHAR_UUID    = UUID.fromString("abcd1234-1234-1234-1234-abcdef123456")

    // ── GATT server state ────────────────────────────────────────────
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private val connectedCentrals = mutableListOf<BluetoothDevice>()

    // ── Store device names from scan results ─────────────────────────
    // Key: device MAC address, Value: friendly name
    private val deviceNameCache = mutableMapOf<String, String>()

    // ── Chunk assembly: deviceAddress → buffer ───────────────────────
    private val chunkBuffers   = mutableMapOf<String, StringBuilder>()
    private val expectedChunks = mutableMapOf<String, Int>()
    private val receivedChunks = mutableMapOf<String, Int>()

    // ── EventChannel sink to send received messages to Flutter ───────
    private var messageSink: EventChannel.EventSink? = null

    // ── Track if server already running to avoid double-start ────────
    private var isServerRunning = false

    // ── BLE Scanner to cache device names ───────────────────────────
    private var nameScanner: BluetoothLeScanner? = null

    // ─────────────────────────────────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupSmsChannel(flutterEngine)
        setupGattChannel(flutterEngine)
        setupMessageEventChannel(flutterEngine)
    }

    // ── AUTO-START: fires as soon as activity is visible ─────────────
    @SuppressLint("MissingPermission")
    override fun onStart() {
        super.onStart()
        if (!isServerRunning) {
            try {
                startGattServer()
                startAdvertising()
                startNameScan() // ← Scan to cache device names
                isServerRunning = true
                Log.d("GATT", "Auto-started GATT server in onStart ✅")
            } catch (e: Exception) {
                Log.e("GATT", "Auto-start failed: ${e.message}")
            }
        }
    }

    // ── Scan nearby devices to cache their names ─────────────────────
    @SuppressLint("MissingPermission")
    private fun startNameScan() {
        try {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            nameScanner = bm.adapter.bluetoothLeScanner

            val scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val address = result.device.address
                    val name = result.scanRecord?.deviceName
                        ?: result.device.name
                        ?: return
                    if (name.isNotEmpty()) {
                        deviceNameCache[address] = name
                        Log.d("GATT", "Cached name: $address → $name")
                    }
                }
            }

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                .build()

            nameScanner?.startScan(null, settings, scanCallback)
            Log.d("GATT", "Name scan started for device name caching ✅")
        } catch (e: Exception) {
            Log.e("GATT", "Name scan failed: ${e.message}")
        }
    }

    // ── Get best available name for a device ─────────────────────────
    @SuppressLint("MissingPermission")
    private fun getDeviceName(device: BluetoothDevice): String {
        // 1. Check our name cache first (from scan results)
        val cachedName = deviceNameCache[device.address]
        if (!cachedName.isNullOrEmpty()) return cachedName

        // 2. Try device.name (works if device was previously bonded/paired)
        val deviceName = try { device.name } catch (e: Exception) { null }
        if (!deviceName.isNullOrEmpty()) return deviceName

        // 3. Fall back to MAC address
        return device.address
    }

    // ════════════════════════════════════════════════════════════════
    // SMS Channel
    // ════════════════════════════════════════════════════════════════
    private fun setupSmsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        ).setMethodCallHandler { call, result ->
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
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                applicationContext.getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                        val parts = smsManager.divideMessage(message)
                        if (parts.size == 1) {
                            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                        } else {
                            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                        }
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
    // GATT Method Channel (Flutter calls these)
    // ════════════════════════════════════════════════════════════════
    @SuppressLint("MissingPermission")
    private fun setupGattChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GATT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "startGattServer" -> {
                    try {
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
                    isServerRunning = false
                    result.success(true)
                }

                "sendMessage" -> {
                    val payload = call.argument<String>("payload")
                    if (payload == null) {
                        result.error("INVALID_ARGS", "Payload is null", null)
                        return@setMethodCallHandler
                    }
                    val sent = notifyAllCentrals(payload)
                    result.success(sent)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // EventChannel (native → Flutter: incoming messages)
    // ════════════════════════════════════════════════════════════════
    private fun setupMessageEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MESSAGE_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                messageSink = sink
                Log.d("GATT", "Flutter is listening for incoming messages ✅")
            }
            override fun onCancel(arguments: Any?) {
                messageSink = null
            }
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

        val service = BluetoothGattService(
            SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        val characteristic = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ  or
            BluetoothGattCharacteristic.PROPERTY_WRITE or
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        val descriptor = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_READ or
            BluetoothGattDescriptor.PERMISSION_WRITE
        )
        characteristic.addDescriptor(descriptor)
        service.addCharacteristic(characteristic)
        gattServer?.addService(service)

        Log.d("GATT", "GATT server started ✅")
    }

    @SuppressLint("MissingPermission")
    private fun stopGattServer() {
        advertiser?.stopAdvertising(advertiseCallback)
        gattServer?.close()
        gattServer = null
        connectedCentrals.clear()
        isServerRunning = false
        Log.d("GATT", "GATT server stopped")
    }

    // ── GATT Server Callback ─────────────────────────────────────────
    @SuppressLint("MissingPermission")
    private val gattServerCallback = object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(
            device: BluetoothDevice, status: Int, newState: Int
        ) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (!connectedCentrals.contains(device)) {
                    connectedCentrals.add(device)
                }

                // ── Use getDeviceName() which checks cache first ──────
                val name = getDeviceName(device)
                Log.d("GATT", "Central connected: $name ✅")

                // Small delay to allow name cache to populate
                Thread.sleep(300)
                val finalName = getDeviceName(device)

                runOnUiThread {
                    messageSink?.success("CLIENT_CONNECTED:$finalName")
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectedCentrals.remove(device)
                chunkBuffers.remove(device.address)
                expectedChunks.remove(device.address)
                receivedChunks.remove(device.address)
                Log.d("GATT", "Central disconnected: ${device.address}")
                runOnUiThread {
                    if (connectedCentrals.isEmpty()) {
                        messageSink?.success("CLIENT_DISCONNECTED")
                    }
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            gattServer?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null
            )

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
                val fullPayload = chunkBuffers[addr].toString()
                chunkBuffers.remove(addr)
                expectedChunks.remove(addr)
                receivedChunks.remove(addr)
                Log.d("GATT", "Full message received from $addr ✅")

                runOnUiThread {
                    messageSink?.success(fullPayload)
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            gattServer?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null
            )
            Log.d("GATT", "Descriptor written by ${device.address} — notifications enabled ✅")
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            gattServer?.sendResponse(
                device, requestId, BluetoothGatt.GATT_SUCCESS, 0,
                "SafeConnect".toByteArray()
            )
        }
    }

    // ── Notify all connected centrals ────────────────────────────────
    @SuppressLint("MissingPermission")
    private fun notifyAllCentrals(payload: String): Boolean {
        val server = gattServer ?: return false
        val service = server.getService(SERVICE_UUID) ?: return false
        val char    = service.getCharacteristic(CHAR_UUID) ?: return false

        if (connectedCentrals.isEmpty()) {
            Log.d("GATT", "No centrals connected — cannot notify")
            return false
        }

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
            Thread.sleep(50)
        }
        Log.d("GATT", "Notified ${connectedCentrals.size} centrals ✅")
        return true
    }

    // ════════════════════════════════════════════════════════════════
    // BLE Advertising
    // ════════════════════════════════════════════════════════════════
    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        advertiser = bm.adapter.bluetoothLeAdvertiser

        if (advertiser == null) {
            Log.e("GATT", "BLE advertising not supported on this device!")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(true)
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)
        Log.d("GATT", "BLE advertising started ✅")
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.d("GATT", "Advertising SUCCESS ✅")
        }
        override fun onStartFailure(errorCode: Int) {
            Log.e("GATT", "Advertising FAILED — error code: $errorCode")
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────
    @SuppressLint("MissingPermission")
    override fun onDestroy() {
        stopGattServer()
        super.onDestroy()
    }
}