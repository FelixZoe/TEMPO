package one.darker.qingxu

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Base64
import androidx.core.content.FileProvider
import one.darker.qingxu.BsPatch
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private val PATCH_CHANNEL = "one.darker.qingxu/patch"
    private val INSTALL_CHANNEL = "one.darker.qingxu/install"
    private val INTEGRITY_CHANNEL = "one.darker.qingxu/integrity"
    private val SCANNER_CHANNEL = "one.darker.qingxu/scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Integrity channel: package, signature, build type and device fingerprint.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> {
                    try {
                        val info = mutableMapOf<String, Any?>()

                        // Package name
                        info["packageName"] = packageName

                        // APK signing certificate SHA-256 fingerprint
                        val signature = getApkSignatureSha256()
                        info["signature"] = signature

                        // Debug build detection
                        info["isDebugBuild"] = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

                        // Device ID (Android ID as fingerprint)
                        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        info["deviceId"] = androidId ?: "unknown"

                        // Version info
                        val pkgInfo = packageManager.getPackageInfo(packageName, 0)
                        info["versionName"] = pkgInfo.versionName
                        info["versionCode"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pkgInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pkgInfo.versionCode.toLong()
                        }

                        // Installer package (to detect sideloading)
                        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            packageManager.getInstallSourceInfo(packageName).installingPackageName
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getInstallerPackageName(packageName)
                        }
                        info["installerPackage"] = installer ?: "unknown"

                        result.success(info)
                    } catch (e: Exception) {
                        result.error("INTEGRITY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ═══ Scanner Channel: launch QR scanner intent ═══
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanQR" -> {
                    try {
                        // Try Google Lens / ZXing scanner
                        val scanIntent = Intent("com.google.zxing.client.android.SCAN")
                        scanIntent.putExtra("SCAN_MODE", "QR_CODE_MODE")
                        if (scanIntent.resolveActivity(packageManager) != null) {
                            startActivityForResult(scanIntent, 0x0000c0de)
                            result.success(null) // Result will come from onActivityResult
                        } else {
                            // Fallback: no scanner app available
                            result.error("NO_SCANNER", "No QR scanner app found. Please install a barcode scanner app.", null)
                        }
                    } catch (e: Exception) {
                        result.error("SCANNER_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ═══ Patch Channel: getApkPath, bspatch, md5 ═══
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PATCH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApkPath" -> {
                    try {
                        val apkPath = applicationInfo.sourceDir
                        result.success(apkPath)
                    } catch (e: Exception) {
                        result.error("APK_PATH_ERROR", e.message, null)
                    }
                }
                "bspatch" -> {
                    val oldPath = call.argument<String>("oldPath")
                    val patchPath = call.argument<String>("patchPath")
                    val newPath = call.argument<String>("newPath")
                    if (oldPath == null || patchPath == null || newPath == null) {
                        result.error("INVALID_ARGS", "Missing oldPath/patchPath/newPath", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            BsPatch.apply(oldPath, newPath, patchPath)
                            runOnUiThread { result.success("ok") }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BSPATCH_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "md5" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val hash = computeMd5(filePath)
                            runOnUiThread { result.success(hash) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MD5_ERROR", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // ═══ Install Channel: installApk ═══
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_VIEW)
                        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        } else {
                            android.net.Uri.fromFile(file)
                        }
                        intent.setDataAndType(uri, "application/vnd.android.package-archive")
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Get APK signing certificate SHA-256 fingerprint.
     * Format: "XX:XX:XX:..." matching keytool -list output.
     */
    private fun getApkSignatureSha256(): String {
        return try {
            val pkgInfo: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.signatures
            }

            if (signatures != null && signatures.isNotEmpty()) {
                val cert = signatures[0].toByteArray()
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(cert)
                digest.joinToString(":") { "%02X".format(it) }
            } else {
                "unknown"
            }
        } catch (e: Exception) {
            "error:${e.message}"
        }
    }

    private fun computeMd5(filePath: String): String {
        val digest = MessageDigest.getInstance("MD5")
        FileInputStream(filePath).use { fis ->
            val buffer = ByteArray(8192)
            var read: Int
            while (fis.read(buffer).also { read = it } != -1) {
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
