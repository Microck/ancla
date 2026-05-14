import java.net.InetAddress
import java.net.UnknownHostException

val localHostAddress = try {
    InetAddress.getByName("127.0.0.1")
} catch (_: UnknownHostException) {
    null
}

if (localHostAddress != null) {
    try {
        java.net.InetAddress::class.java.getDeclaredField("cachedLocalHost").apply {
            isAccessible = true
            set(null, localHostAddress)
        }
    } catch (_: Throwable) {
    }
}
