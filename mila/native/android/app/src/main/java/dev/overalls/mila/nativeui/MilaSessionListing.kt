package dev.overalls.mila.nativeui

import java.util.UUID

data class MilaMachineRow(val id: UUID, val name: String, val status: String)
data class MilaSessionListing(val machines: List<MilaMachineRow>, val hasMore: Boolean) {
    companion object {
        private const val MAX_DISPLAY_BYTES = 128

        private fun boundedDisplay(value: String, fallback: String): String {
            val candidate = if (value.isEmpty()) fallback else value
            require(candidate.toByteArray(Charsets.UTF_8).size <= MAX_DISPLAY_BYTES) { "display text exceeds bound" }
            require(candidate.none { it.isISOControl() }) { "display text contains control character" }
            return candidate
        }

        fun decode(bytes: ByteArray): MilaSessionListing {
            require(bytes.size <= 8 * 1024 * 1024) { "listing exceeds bound" }
            val source = bytes.toString(Charsets.UTF_8)
            require(source.startsWith("{\"machines\":[")) { "machines missing" }
            val end = source.indexOf(']')
            require(end >= 0) { "machines missing" }
            val body = source.substring(13, end)
            if (body.isBlank()) return MilaSessionListing(emptyList(), source.contains("\"has_more\":true"))
            val rows = body.split("},{")
            require(rows.size <= 10_000) { "too many machines" }
            val machines = rows.map { raw ->
                val row = raw.trim('{', '}')
                fun field(name: String): String? = Regex("\\\"$name\\\":\\\"([^\\\"]*)\\\"").find(row)?.groupValues?.get(1)
                val id = runCatching { UUID.fromString(field("id") ?: throw IllegalArgumentException("invalid machine id")) }.getOrElse { throw IllegalArgumentException("invalid machine id", it) }
                val name = boundedDisplay(field("name") ?: id.toString(), id.toString())
                val status = boundedDisplay(field("status") ?: "unknown", "unknown")
                MilaMachineRow(id, name, status)
            }
            val truncated = machines.size > 256
            return MilaSessionListing(machines.take(256), source.contains("\"has_more\":true") || truncated)
        }
    }
}

/** Typed projection of a Rust listing; malformed or oversized native data is refused. */
fun MilaSessionHandle.decodeListing(): MilaSessionListing = MilaSessionListing.decode(listing())
