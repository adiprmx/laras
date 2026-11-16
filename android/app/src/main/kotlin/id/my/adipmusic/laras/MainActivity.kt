package id.my.adipmusic.laras

import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val storageChannel = "id.my.adipmusic.laras/storage"

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
    }
}
