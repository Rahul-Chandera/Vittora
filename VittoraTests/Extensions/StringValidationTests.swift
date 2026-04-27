import Testing
@testable import Vittora

@Suite("String Validation Tests")
struct StringValidationTests {
    @Test("HTTP and HTTPS URLs are accepted")
    func acceptsWebURLs() {
        #expect("https://vittora.app".isValidURL)
        #expect("http://example.com/path?q=1".isValidURL)
    }

    @Test("Non-web URL schemes are rejected")
    func rejectsNonWebSchemes() {
        #expect("file:///tmp/private.pdf".isValidURL == false)
        #expect("javascript:alert(1)".isValidURL == false)
        #expect("mailto:test@example.com".isValidURL == false)
    }
}
