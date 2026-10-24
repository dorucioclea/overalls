package dev.overalls.mila.nativeui

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Durable, validated deployment selection. Credentials and tokens never enter this store. */
interface MilaDeploymentStore {
    fun read(): MilaDeployment?
  fun readAll(): List<MilaDeployment> = listOfNotNull(read())
    fun write(deployment: MilaDeployment)
  fun remove(deployment: MilaDeployment) { if (read() == deployment) clear() }
    fun clear()
    fun readApproval(): MilaApprovalState = MilaApprovalState.NotRequired
    fun writeApproval(state: MilaApprovalState) {}
}

class MilaSharedPreferencesDeploymentStore(private val preferences: SharedPreferences) : MilaDeploymentStore {
    override fun read(): MilaDeployment? {
    val values = readAll(); val selected = preferences.getString(KEY_SELECTED, null)
    return values.firstOrNull { "${it.host}:${it.port}" == selected } ?: values.firstOrNull()
    }

  override fun readAll(): List<MilaDeployment> {
    val encoded = preferences.getString(KEY_ENTRIES, null)
    if (encoded != null) return runCatching {
      val array = JSONArray(encoded)
      (0 until array.length()).mapNotNull { index ->
        val item = array.optJSONObject(index) ?: return@mapNotNull null
        runCatching { MilaDeployment(item.getString("host"), item.getInt("port"), item.getString("label")) }.getOrNull()
      }.distinctBy { it.host to it.port }
    }.getOrDefault(emptyList())
    val host = preferences.getString(KEY_HOST, null) ?: return emptyList()
    return runCatching { listOf(MilaDeployment(host, preferences.getInt(KEY_PORT, 22), preferences.getString(KEY_LABEL, host) ?: host)) }.getOrDefault(emptyList())
  }

    override fun write(deployment: MilaDeployment) {
    val values = readAll().filterNot { it.host == deployment.host && it.port == deployment.port } + deployment
    val array = JSONArray().apply { values.forEach { put(JSONObject().put("host", it.host).put("port", it.port).put("label", it.label)) } }
    preferences.edit().putString(KEY_ENTRIES, array.toString()).putString(KEY_SELECTED, "${deployment.host}:${deployment.port}").apply()
    }

  override fun remove(deployment: MilaDeployment) {
    val values = readAll().filterNot { it.host == deployment.host && it.port == deployment.port }
    val edit = preferences.edit()
    if (values.isEmpty()) edit.remove(KEY_ENTRIES).remove(KEY_SELECTED).remove(KEY_HOST).remove(KEY_PORT).remove(KEY_LABEL)
    else edit.putString(KEY_ENTRIES, JSONArray().apply { values.forEach { put(JSONObject().put("host", it.host).put("port", it.port).put("label", it.label)) } }.toString())
      .putString(KEY_SELECTED, "${values.first().host}:${values.first().port}")
    edit.apply()
  }
  override fun clear() { preferences.edit().remove(KEY_ENTRIES).remove(KEY_SELECTED).remove(KEY_HOST).remove(KEY_PORT).remove(KEY_LABEL).apply() }
    override fun readApproval(): MilaApprovalState = runCatching {
        MilaApprovalState.valueOf(preferences.getString(KEY_APPROVAL, MilaApprovalState.NotRequired.name)!!)
    }.getOrDefault(MilaApprovalState.NotRequired)
    override fun writeApproval(state: MilaApprovalState) { preferences.edit().putString(KEY_APPROVAL, state.name).apply() }

  private companion object { const val KEY_HOST = "host"; const val KEY_PORT = "port"; const val KEY_LABEL = "label"; const val KEY_ENTRIES = "entries"; const val KEY_SELECTED = "selected"; const val KEY_APPROVAL = "approval" }
}

/** Session approval is explicit and survives reconnect attempts without persisting secrets. */
enum class MilaApprovalState { NotRequired, Pending, Approved, Rejected, Expired }
