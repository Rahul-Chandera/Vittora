import Foundation
import Security
import Testing
import VittoraCore
@testable import Vittora

@Suite("SecurityErrorMapper Tests")
struct SecurityErrorMapperTests {

    @Test("OSStatus is not exposed in user-facing message")
    func osStatusNotExposed() {
        let error = SecurityErrorMapper.encryptionFailed(.keychainSave, osStatus: errSecAuthFailed)
        let description = error.errorDescription ?? ""
        #expect(description.contains("-25293") == false)
        #expect(description.contains("errSec") == false)
        #expect(description.contains("OSStatus") == false)
    }

    @Test("CFError description is not exposed in user-facing message")
    func cfErrorNotExposed() {
        let cfError = CFErrorCreate(
            nil,
            "com.apple.security" as CFString,
            -25293,
            nil
        )
        let error = SecurityErrorMapper.encryptionFailed(.secureEnclaveSetup, cfError: cfError)
        let description = error.errorDescription ?? ""
        #expect(description.contains("com.apple.security") == false)
        #expect(description.contains("-25293") == false)
        #expect(description.contains("Failed to generate keypair") == false)
    }

    @Test("underlying error description is not exposed in user-facing message")
    func underlyingErrorNotExposed() {
        let underlying = NSError(domain: "NSOSStatusErrorDomain", code: -25293)
        let error = SecurityErrorMapper.encryptionFailed(.decrypt, underlying: underlying)
        let description = error.errorDescription ?? ""
        #expect(description.contains("NSOSStatusErrorDomain") == false)
        #expect(description.contains("-25293") == false)
    }

    @Test("user messages are non-empty and localized")
    func userMessagesNonEmpty() {
        let contexts: [SecurityErrorContext] = [
            .keychainSave,
            .secureEnclaveSetup,
            .secureEnclaveUnwrap,
            .decrypt,
        ]
        for context in contexts {
            #expect(SecurityErrorMapper.userMessage(for: context).isEmpty == false)
        }
    }
}
