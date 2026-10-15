package dev.katriyda.lampsmart

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 把一条 31 字节控制帧塞进 BLE Legacy 广播（ADV_IND）。
 *
 * 容量边界（决定了这里不能做别的）：
 *   3（Flags AD）+ 2（UUID 列表 AD 头）+ 26（13 × 16-bit UUID）= 31 字节，
 *   正好等于 [AdvertiseData] 的 31 字节上限。所以**不能**再追加 Manufacturer Specific Data，
 *   也**不能** `setIncludeDeviceName(true)` —— 原厂 App 就是这么塞的（报告 §3.1）。
 */
class AdvertiserPlugin(private val activity: Activity) {

    companion object {
        private const val CHANNEL = "dev.katriyda.lampsmart/adv"
        private const val REQUEST_CODE = 0x5AFE
        private const val MAX_UUIDS = 13
    }

    private var pendingPermission: MethodChannel.Result? = null
    private var advertising = false

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensurePermission" -> ensurePermission(result)
            "advertise" -> advertise(call, result)
            "stop" -> {
                stopAdvertising()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --------------------------------------------------------------- 权限

    private fun ensurePermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(mapOf("granted" to true))
            return
        }
        if (pendingPermission != null) {
            result.error("in_progress", "权限申请正在进行中", null)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, requiredPermissions(), REQUEST_CODE)
    }

    /** 由 [MainActivity.onRequestPermissionsResult] 转发；返回 true 表示已消费。 */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermission?.success(mapOf("granted" to granted))
        pendingPermission = null
        return true
    }

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            arrayOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
        }

    private fun hasPermission(): Boolean = requiredPermissions().all {
        ActivityCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun adapter(): BluetoothAdapter? =
        (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // --------------------------------------------------------------- 广播

    private fun advertise(call: MethodCall, result: MethodChannel.Result) {
        val uuids = call.argument<List<String>>("uuids")
        if (uuids == null || uuids.size != MAX_UUIDS) {
            result.error("bad_args", "需要恰好 $MAX_UUIDS 个 UUID", null)
            return
        }
        if (!hasPermission()) {
            result.error("permission", "缺少 BLUETOOTH_ADVERTISE 权限", null)
            return
        }
        val adapter = adapter()
        val advertiser = adapter?.bluetoothLeAdvertiser
        if (adapter == null || advertiser == null || !adapter.isEnabled) {
            result.success(false)
            return
        }
        val durationMs = (call.argument<Int>("durationMs") ?: 300).coerceAtLeast(1)

        val dataBuilder = AdvertiseData.Builder()
        for (uuid in uuids) {
            dataBuilder.addServiceUuid(ParcelUuid.fromString(uuid))
        }
        val settingsBuilder = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setTimeout(durationMs)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // setConnectable 是 API 26+；低版本本来就不可能被连上，不设即可。
            settingsBuilder.setConnectable(false)
        }

        advertiser.startAdvertising(
            dataBuilder.build(),
            settingsBuilder.build(),
            object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    advertising = true
                    activity.runOnUiThread { result.success(true) }
                }

                override fun onStartFailure(errorCode: Int) {
                    advertising = false
                    activity.runOnUiThread { result.success(false) }
                }
            }
        )
    }

    private fun stopAdvertising() {
        if (!advertising) {
            return
        }
        advertising = false
        adapter()?.bluetoothLeAdvertiser?.stopAdvertising(AdvertiseCallback())
    }
}