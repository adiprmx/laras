package id.my.adipmusic.laras

import android.content.Context
import android.content.Intent
import android.media.audiofx.Equalizer
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
    private val deepLinkChannel = "id.my.adipmusic.laras/deep_link"
    private val equalizerChannel = "id.my.adipmusic.laras/equalizer"

    // P7 (MUST #13): tautan dalam. Sink EventChannel + tautan yang tiba
    // sebelum Dart mendengarkan (cold start / onNewIntent lebih dulu).
    private var deepLinkSink: EventChannel.EventSink? = null
    private var pendingDeepLink: String? = null
    private var initialDeepLinkSent = false

    // P7: equalizer perangkat (satu instance, ditempel ke session id
    // yang dikirim Dart). Null bila belum di-init / tidak tersedia.
    private var equalizer: Equalizer? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // singleTop: tautan yang dibuka saat app sudah jalan tiba di sini.
        if (intent.action == Intent.ACTION_VIEW) {
            intent.data?.toString()?.let { link ->
                deepLinkSink?.success(link) ?: run { pendingDeepLink = link }
            }
        }
    }

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
        // P7 (MUST #13): tautan dalam — meneruskan URL tautan YouTube ke
        // Dart (DeepLinkService). Cold start: intent awal dikirim sekali
        // saat Dart pertama mendengarkan. Tautan yang tiba sebelum ada
        // pendengar disimpan sebagai pending (bukan hilang).
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannel,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deepLinkSink = events
                    val pending = pendingDeepLink
                    pendingDeepLink = null
                    if (pending != null) {
                        events?.success(pending)
                    } else if (!initialDeepLinkSent) {
                        initialDeepLinkSent = true
                        intent?.takeIf { it.action == Intent.ACTION_VIEW }
                            ?.data?.toString()?.let { link ->
                                events?.success(link)
                            }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkSink = null
                }
            },
        )
        // P7: equalizer — android.media.audiofx.Equalizer ditempel ke
        // audio session id yang dikirim Dart (dari just_audio). Semua
        // angka dikirim sebagai Int (bukan Short): codec channel tidak
        // mendukung Short. Bila perangkat tidak menyediakan efek ini,
        // konstruktor Equalizer melempar dan init menjawab
        // available=false (Dart menampilkan pesan jujur).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            equalizerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val sessionId = call.argument<Int>("sessionId")
                    if (sessionId == null) {
                        result.error("BAD_SESSION", "sessionId kosong", null)
                        return@setMethodCallHandler
                    }
                    try {
                        equalizer?.release()
                        val eq = Equalizer(0, sessionId)
                        equalizer = eq
                        val bandCount = eq.numberOfBands.toInt()
                        val freqs = (0 until bandCount).map {
                            eq.getCenterFreq(it.toShort())
                        }
                        val levels = (0 until bandCount).map {
                            eq.getBandLevel(it.toShort()).toInt()
                        }
                        val presets = (0 until eq.numberOfPresets.toInt()).map {
                            eq.getPresetName(it.toShort())
                        }
                        val range = eq.bandLevelRange
                        result.success(
                            mapOf(
                                "available" to true,
                                "centerFreqs" to freqs,
                                "levels" to levels,
                                "minLevel" to range[0].toInt(),
                                "maxLevel" to range[1].toInt(),
                                "presets" to presets,
                                "currentPreset" to eq.currentPreset.toInt(),
                            ),
                        )
                    } catch (e: Exception) {
                        equalizer = null
                        result.success(mapOf("available" to false))
                    }
                }
                "setEnabled" -> {
                    val eq = equalizer
                    if (eq == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        eq.enabled = call.argument<Boolean>("enabled") ?: false
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setPreset" -> {
                    val eq = equalizer
                    if (eq == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val preset = call.argument<Int>("preset") ?: -1
                    try {
                        eq.usePreset(preset.toShort())
                        val bandCount = eq.numberOfBands.toInt()
                        result.success(
                            (0 until bandCount).map {
                                eq.getBandLevel(it.toShort()).toInt()
                            },
                        )
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "setBandLevel" -> {
                    val eq = equalizer
                    if (eq == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val band = call.argument<Int>("band") ?: -1
                    val level = call.argument<Int>("level") ?: 0
                    try {
                        eq.setBandLevel(band.toShort(), level.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "release" -> {
                    try {
                        equalizer?.release()
                    } catch (e: Exception) {
                        // Lepas yang gagal tidak masalah: init berikutnya
                        // membuat instance baru.
                    }
                    equalizer = null
                    result.success(null)
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
