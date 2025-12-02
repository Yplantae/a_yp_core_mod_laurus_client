package com.yplantae.core.mod.laurus.a_yp_core_mod_laurus_client

import android.os.Bundle
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity: FlutterActivity() {
    private val CHANNEL = "security_detection"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEmulator" -> result.success(isEmulator()) // ✅ 에뮬레이터 감지
                "isHookDetected" -> result.success(detectFridaOrXposed()) // ✅ Frida/Xposed 감지
                "isRooted" -> result.success(isDeviceRooted()) // ✅ 루팅 감지
                "isFileTampered" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val expectedHash = call.argument<String>("expectedHash") ?: ""
                    result.success(isFileTampered(filePath, expectedHash))
                } // ✅ 파일 변조 감지
                else -> result.notImplemented()
            }
        }
    }

    /// ✅ 1. 에뮬레이터 감지
    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.lowercase().contains("emulator")
                || Build.BRAND.lowercase().contains("generic")
                || Build.HARDWARE.lowercase().contains("goldfish"))
    }

    /// ✅ 2. Frida & Xposed 감지
    private fun detectFridaOrXposed(): Boolean {
        try {
            val processList = arrayOf("frida", "xposed", "substrate")
            val process = Runtime.getRuntime().exec("ps")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()
            return processList.any { output.contains(it) }
        } catch (e: Exception) {
            return false
        }
    }

    /// ✅ 3. 루팅 감지
    private fun isDeviceRooted(): Boolean {
        val rootPaths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su"
        )
        return rootPaths.any { File(it).exists() }
    }

    /// ✅ 4. 파일 변조 감지 (해시 검증)
    private fun isFileTampered(filePath: String, expectedHash: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return true
            val hash = file.inputStream().use { it.readBytes().toString(Charsets.UTF_8) }
            hash != expectedHash
        } catch (e: Exception) {
            true
        }
    }
}
