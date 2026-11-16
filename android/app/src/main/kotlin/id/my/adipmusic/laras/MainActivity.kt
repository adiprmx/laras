package id.my.adipmusic.laras

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val storageChannel = "id.my.adipmusic.laras/storage"
    private val connectivityChannel = "id.my.adipmusic.laras/connectivity"
    private val connectivityEventsChannel =
        "id.my.adipmusic.laras/connectivity_events"
    private val externalChannel = "id.my.adipmusic.laras/external"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // P5: sisa ruang penyimpanan (StatFs) untuk pra-cek unduhan.
        // Dart memanggil method "freeBytes" dengan argumen path; bila
        // gagal, Dart mendapat error dan melewati pra-cek (ENOSPC di
        // tengah unduhan tetap ditangani sebagai kegagalan jujur).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            storageChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("BAD_PATH", "path kosong", null)
                        return@setMethodCallHandler
                    }
                    try {
                        // availableBytes ada sejak API 18; minSdk 26.
                        val free = StatFs(path).availableBytes
                        result.success(free)
                    } catch (e: IllegalArgumentException) {
                        result.error("BAD_PATH", e.message, null)
                    } catch (e: Exception) {
                        result.error("STATFS_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // P6: deteksi WiFi untuk sakelar "Unduh saat WiFi saja" (B8.4).
        // isWifi menjawab status saat ini; EventChannel mengalirkan
        // perubahan (NetworkCallback). Hotspot HP (berbasis seluler)
        // tetap terdeteksi sebagai WiFi oleh Android — keterbatasan
        // yang dicatat di FAQ, bukan disembunyikan.
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            connectivityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWifi" -> {
                    try {
                        result.success(isWifi(connectivityManager))
                    } catch (e: Exception) {
                        result.error("WIFI_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            connectivityEventsChannel,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var callback: ConnectivityManager.NetworkCallback? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val networkCallback =
                        object : ConnectivityManager.NetworkCallback() {
                            override fun onAvailable(network: Network) {
                                events?.success(isWifi(connectivityManager))
                            }

                            override fun onLost(network: Network) {
                                events?.success(isWifi(connectivityManager))
                            }

                            override fun onCapabilitiesChanged(
                                network: Network,
                                capabilities: NetworkCapabilities,
                            ) {
                                events?.success(isWifi(connectivityManager))
                            }
                        }
                    callback = networkCallback
                    val request = NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        .build()
                    connectivityManager.registerNetworkCallback(request, networkCallback)
                    // Kirim status awal segera supaya Dart tidak menunggu
                    // perubahan pertama.
                    events?.success(isWifi(connectivityManager))
                }

                override fun onCancel(arguments: Any?) {
                    callback?.let { connectivityManager.unregisterNetworkCallback(it) }
                    callback = null
                }
            },
        )
        // P6: tautan keluar app — email laporan kerusakan, tautan repo,
        // info perangkat. Daftar izin tautan diberlakukan di sisi Dart.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            externalChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openMail" -> {
                    val to = call.argument<String>("to").orEmpty()
                    val subject = call.argument<String>("subject").orEmpty()
                    val body = call.argument<String>("body").orEmpty()
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:$to")
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                        putExtra(Intent.EXTRA_TEXT, body)
                    }
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        result.success(true)
                    } else {
                        // Tidak ada aplikasi email: Dart menyalin alamat
                        // ke clipboard + menampilkan pesan.
                        result.success(false)
                    }
                }
                "openLink" -> {
                    val url = call.argument<String>("url").orEmpty()
                    if (url.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse(url),
                        )
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "deviceInfo" -> {
                    result.success(
                        mapOf(
                            "model" to Build.MODEL,
                            "androidVersion" to Build.VERSION.RELEASE,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isWifi(connectivityManager: ConnectivityManager): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities =
            connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }
}
