package com.guoguo.guoguo_forward

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.Settings
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val pickWorksheetRequestCode = 4017
    private val pickStudyMaterialRequestCode = 4018
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private var mediaPlayer: MediaPlayer? = null
    private var oneShotPlayer: MediaPlayer? = null
    private var oneShotResult: MethodChannel.Result? = null
    private var pickWorksheetResult: MethodChannel.Result? = null
    private var pickStudyMaterialResult: MethodChannel.Result? = null
    private var currentBgmKey: String? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "guoguo_forward/audio"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "preload" -> {
                    preloadSounds()
                    result.success(null)
                }
                "playSfx", "play" -> {
                    preloadSounds()
                    val key = call.arguments as? String
                    val soundId = soundIds[key]
                    if (soundId != null) {
                        soundPool?.play(soundId, 0.75f, 0.75f, 1, 0, 1f)
                    }
                    result.success(null)
                }
                "playBgm" -> {
                    val key = call.arguments as? String ?: "menu"
                    playBgm(key)
                    result.success(null)
                }
                "playOneShot" -> {
                    val key = call.arguments as? String ?: ""
                    playOneShot(key, result)
                }
                "stopBgm" -> {
                    stopBgm()
                    result.success(null)
                }
                "speakEnglish" -> {
                    val text = call.arguments as? String ?: ""
                    speakEnglish(text)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "guoguo_forward/files"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickWorksheetJson" -> pickWorksheetJson(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "guoguo_forward/study_materials"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickStudyMaterialPdf" -> pickStudyMaterialPdf(result)
                "cacheBundledPdf" -> {
                    val args = call.arguments as? Map<*, *>
                    val fileName = args?.get("fileName") as? String ?: "study_material.pdf"
                    val bytes = args?.get("bytes") as? ByteArray
                    if (bytes == null) {
                        result.error("bad_args", "资料文件内容为空。", null)
                    } else {
                        result.success(writeStudyMaterialBytes(fileName, bytes, "bundled").absolutePath)
                    }
                }
                "pdfPageCount" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String ?: ""
                    result.success(pdfPageCount(path))
                }
                "renderPdfPage" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String ?: ""
                    val pageIndex = (args?.get("pageIndex") as? Int) ?: 0
                    val widthPx = (args?.get("widthPx") as? Int) ?: 1200
                    try {
                        result.success(renderPdfPage(path, pageIndex, widthPx))
                    } catch (error: Exception) {
                        result.error("render_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "guoguo_forward/update"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAppInfo" -> result.success(appInfoMap())
                    "getApkPath" -> {
                        val fileName = call.arguments as? String ?: "guoguo_update.apk"
                        result.success(updateApkFile(fileName).absolutePath)
                    }
                    "sha256File" -> {
                        val path = call.arguments as? String ?: ""
                        result.success(sha256File(path))
                    }
                    "canInstallPackages" -> result.success(canInstallUpdatePackages())
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.arguments as? String ?: ""
                        installApk(path)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("update_failed", error.message, null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun appInfoMap(): Map<String, Any> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            info.versionCode
        }
        return mapOf(
            "versionName" to (info.versionName ?: "0.0.0"),
            "versionCode" to versionCode
        )
    }

    private fun updateApkFile(fileName: String): File {
        val safeName = fileName.replace(Regex("[\\\\/:*?\"<>|]+"), "_")
        val dir = File(cacheDir, "updates").apply { mkdirs() }
        return File(dir, safeName)
    }

    private fun sha256File(path: String): String {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("APK 文件不存在。")
        }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun canInstallUpdatePackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("APK 文件不存在。")
        }
        if (!canInstallUpdatePackages()) {
            openInstallPermissionSettings()
            throw IllegalStateException("需要先允许本应用安装未知应用。")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    private fun pickWorksheetJson(result: MethodChannel.Result) {
        if (pickWorksheetResult != null) {
            result.error("busy", "正在选择文件，请先完成当前操作。", null)
            return
        }
        pickWorksheetResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/json", "text/plain", "application/octet-stream")
            )
        }
        try {
            startActivityForResult(intent, pickWorksheetRequestCode)
        } catch (error: Exception) {
            pickWorksheetResult = null
            result.error("open_failed", error.message, null)
        }
    }

    private fun pickStudyMaterialPdf(result: MethodChannel.Result) {
        if (pickStudyMaterialResult != null) {
            result.error("busy", "正在选择文件，请先完成当前操作。", null)
            return
        }
        pickStudyMaterialResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf"))
        }
        try {
            startActivityForResult(intent, pickStudyMaterialRequestCode)
        } catch (error: Exception) {
            pickStudyMaterialResult = null
            result.error("open_failed", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android API, still supported by FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickWorksheetRequestCode) {
            val pending = pickWorksheetResult
            pickWorksheetResult = null
            if (pending == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            try {
                val uri = data.data!!
                val text = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)
                    ?.use { it.readText() }
                pending.success(text)
            } catch (error: Exception) {
                pending.error("read_failed", error.message, null)
            }
            return
        }
        if (requestCode == pickStudyMaterialRequestCode) {
            val pending = pickStudyMaterialResult
            pickStudyMaterialResult = null
            if (pending == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            try {
                val uri = data.data!!
                val fileName = displayNameForUri(uri.toString()) ?: "study_material.pdf"
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes == null || bytes.isEmpty()) {
                    pending.error("read_failed", "文件内容为空。", null)
                    return
                }
                val file = writeStudyMaterialBytes(fileName, bytes, "imported")
                pending.success(
                    mapOf(
                        "path" to file.absolutePath,
                        "fileName" to fileName,
                        "sizeBytes" to file.length().toInt()
                    )
                )
            } catch (error: Exception) {
                pending.error("read_failed", error.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun displayNameForUri(uriText: String): String? {
        val uri = android.net.Uri.parse(uriText)
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) cursor.getString(nameIndex) else null
        }
    }

    private fun writeStudyMaterialBytes(fileName: String, bytes: ByteArray, bucket: String): File {
        val safeName = fileName.replace(Regex("[\\\\/:*?\"<>|]+"), "_")
        val dir = File(filesDir, "study_materials/$bucket").apply { mkdirs() }
        val targetName = if (bucket == "imported") {
            "${System.currentTimeMillis()}_$safeName"
        } else {
            safeName
        }
        val file = File(dir, targetName)
        file.writeBytes(bytes)
        return file
    }

    private fun pdfPageCount(path: String): Int {
        val file = File(path)
        if (!file.exists()) return 0
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        descriptor.use {
            PdfRenderer(it).use { renderer ->
                return renderer.pageCount
            }
        }
    }

    private fun renderPdfPage(path: String, pageIndex: Int, widthPx: Int): ByteArray {
        val file = File(path)
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        descriptor.use {
            PdfRenderer(it).use { renderer ->
                val safeIndex = pageIndex.coerceIn(0, renderer.pageCount - 1)
                renderer.openPage(safeIndex).use { page ->
                    val safeWidth = widthPx.coerceIn(480, 2200)
                    val safeHeight = (safeWidth.toFloat() * page.height / page.width).toInt()
                        .coerceAtLeast(1)
                    val bitmap = Bitmap.createBitmap(
                        safeWidth,
                        safeHeight,
                        Bitmap.Config.ARGB_8888
                    )
                    Canvas(bitmap).drawColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 92, stream)
                    bitmap.recycle()
                    return stream.toByteArray()
                }
            }
        }
    }

    private fun preloadSounds() {
        if (soundPool != null) return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(attributes)
            .build()
        soundPool = pool
        soundIds["tap"] = pool.load(this, R.raw.ui_tap, 1)
        soundIds["correct"] = pool.load(this, R.raw.ui_correct, 1)
        soundIds["wrong"] = pool.load(this, R.raw.ui_wrong, 1)
        soundIds["hint"] = pool.load(this, R.raw.ui_hint, 1)
        soundIds["erase"] = pool.load(this, R.raw.ui_erase, 1)
        soundIds["reward"] = pool.load(this, R.raw.ui_reward, 1)
        soundIds["brush"] = pool.load(this, R.raw.ui_brush, 1)
        soundIds["page"] = pool.load(this, R.raw.ui_page, 1)
        soundIds["chime"] = pool.load(this, R.raw.ui_chime, 1)
        soundIds["voice"] = pool.load(this, R.raw.ui_voice, 1)
        soundIds["pet_cute"] = pool.load(this, R.raw.ui_pet_cute, 1)
        soundIds["pet_charge"] = pool.load(this, R.raw.ui_pet_charge, 1)
        soundIds["pet_projectile"] = pool.load(this, R.raw.ui_pet_projectile, 1)
        soundIds["pet_attack"] = pool.load(this, R.raw.ui_pet_attack, 1)
        soundIds["magic_impact"] = pool.load(this, R.raw.ui_magic_impact, 1)
        soundIds["boss_charge"] = pool.load(this, R.raw.ui_boss_charge, 1)
        soundIds["boss_attack"] = pool.load(this, R.raw.ui_boss_attack, 1)
        soundIds["shield_hit"] = pool.load(this, R.raw.ui_shield_hit, 1)
        soundIds["dizzy"] = pool.load(this, R.raw.ui_dizzy, 1)
        soundIds["hit"] = pool.load(this, R.raw.ui_hit, 1)
        soundIds["boss_down"] = pool.load(this, R.raw.ui_boss_down, 1)
        soundIds["boss_escape"] = pool.load(this, R.raw.ui_boss_escape, 1)
        soundIds["steal"] = pool.load(this, R.raw.ui_steal, 1)
        soundIds["feed"] = pool.load(this, R.raw.ui_feed, 1)
        soundIds["gomoku_stone"] = pool.load(this, R.raw.ui_gomoku_stone, 1)
        soundIds["gomoku_player_stone"] = pool.load(this, R.raw.ui_gomoku_player_stone, 1)
        soundIds["gomoku_ai_stone"] = pool.load(this, R.raw.ui_gomoku_ai_stone, 1)
        soundIds["game_fail"] = pool.load(this, R.raw.ui_game_fail, 1)
    }

    private fun playOneShot(key: String, result: MethodChannel.Result) {
        val resId = when (key) {
            "victory" -> R.raw.ui_victory
            "pet_click" -> R.raw.ui_pet_click
            "sudoku_victory" -> R.raw.ui_sudoku_victory
            "game_complete" -> R.raw.ui_game_complete
            else -> 0
        }
        if (resId == 0) {
            result.success(null)
            return
        }
        oneShotResult?.success(null)
        oneShotResult = result
        oneShotPlayer?.stop()
        oneShotPlayer?.release()
        oneShotPlayer = MediaPlayer.create(this, resId)?.apply {
            val volume = if (key == "sudoku_victory") 0.45f else 0.95f
            setVolume(volume, volume)
            setOnCompletionListener { player ->
                player.release()
                if (oneShotPlayer == player) oneShotPlayer = null
                if (oneShotResult == result) {
                    oneShotResult = null
                    result.success(null)
                }
            }
            setOnErrorListener { player, _, _ ->
                player.release()
                if (oneShotPlayer == player) oneShotPlayer = null
                if (oneShotResult == result) {
                    oneShotResult = null
                    result.success(null)
                }
                true
            }
            start()
        }
        if (oneShotPlayer == null) {
            if (oneShotResult == result) oneShotResult = null
            result.success(null)
        }
    }

    private fun playBgm(key: String) {
        if (currentBgmKey == key && mediaPlayer?.isPlaying == true) return
        stopBgm()
        val dynamicLevelResId = resources.getIdentifier(
            "bgm_${key.lowercase(Locale.US).replace(Regex("[^a-z0-9]+"), "_").trim('_')}",
            "raw",
            packageName
        )
        val resId = if (dynamicLevelResId != 0) dynamicLevelResId else when (key) {
            "home", "menu" -> R.raw.bgm_menu
            "math", "mach" -> R.raw.bgm_mach
            "chinese", "yw" -> R.raw.bgm_yw
            "english", "sd1" -> R.raw.bgm_sd1
            "sudoku", "sd" -> R.raw.bgm_sd
            "wrong_challenge", "ct" -> R.raw.bgm_ct
            "self_challenge", "tz" -> R.raw.bgm_tz
            "shop", "shoping" -> R.raw.bgm_shoping
            "boss", "boss_user" -> R.raw.bgm_boss_user
            "memory_flip" -> R.raw.bgm_memory_flip
            "gomoku" -> R.raw.bgm_gomoku
            else -> R.raw.bgm_menu
        }
        mediaPlayer = MediaPlayer.create(this, resId)?.apply {
            isLooping = true
            setVolume(0.28f, 0.28f)
            start()
        }
        currentBgmKey = key
    }

    private fun stopBgm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        currentBgmKey = null
    }

    private fun speakEnglish(text: String) {
        if (text.isBlank()) return
        val engine = tts
        if (engine == null) {
            ttsReady = false
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val value = tts?.setLanguage(Locale.US)
                    ttsReady = value != TextToSpeech.LANG_MISSING_DATA &&
                        value != TextToSpeech.LANG_NOT_SUPPORTED
                    tts?.setSpeechRate(0.82f)
                    if (ttsReady) {
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "english_question")
                    }
                }
            }
            return
        }
        if (!ttsReady) return
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "english_question")
    }

    override fun onDestroy() {
        stopBgm()
        oneShotPlayer?.stop()
        oneShotPlayer?.release()
        oneShotPlayer = null
        oneShotResult?.success(null)
        oneShotResult = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        soundPool?.release()
        soundPool = null
        soundIds.clear()
        super.onDestroy()
    }
}
