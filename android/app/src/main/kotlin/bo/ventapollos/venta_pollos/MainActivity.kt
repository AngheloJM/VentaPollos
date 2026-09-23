package bo.ventapollos.venta_pollos

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bo.ventapollos/dispositivo")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    // ANDROID_ID se conserva al reinstalar la app o borrar sus datos;
                    // solo cambia con un restablecimiento de fábrica.
                    "androidId" -> resultado.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                    "modelo" -> resultado.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    else -> resultado.notImplemented()
                }
            }
    }
}
