import Foundation
import CryptoKit

/// A Swift implementation of the Fernet encryption/decryption (minimal for decryption only).
/// Fernet is a specific format of AES-128-CBC with HMAC-SHA256.
struct FernetDecryptor {
    
    enum FernetError: Error {
        case invalidToken
        case invalidKey
        case signatureMismatch
        case decryptionFailed
    }
    
    /// Decrypts a Fernet token using the provided master key.
    /// - Parameters:
    ///   - token: The base64-urlsafe encoded Fernet token.
    ///   - key: The base64-urlsafe encoded 32-byte master key.
    static func decrypt(token: String, key: String) throws -> String {
        guard let tokenData = Data(base64URLEncoded: token),
              let keyData = Data(base64URLEncoded: key),
              keyData.count == 32 else {
            throw FernetError.invalidToken
        }
        
        // Fernet Key format: [16-byte HMAC key][16-byte AES key]
        let signingKey = keyData.subdata(in: 0..<16)
        let encryptionKey = keyData.subdata(in: 16..<32)
        
        // Fernet Token format:
        // [1-byte version (0x80)][8-byte timestamp][16-byte IV][ciphertext][32-byte HMAC]
        guard tokenData.count >= 1 + 8 + 16 + 32, tokenData[0] == 0x80 else {
            throw FernetError.invalidToken
        }
        
        let iv = tokenData.subdata(in: 9..<25)
        let ciphertext = tokenData.subdata(in: 25..<(tokenData.count - 32))
        let signature = tokenData.subdata(in: (tokenData.count - 32)..<tokenData.count)
        
        // 1. Verify HMAC
        let dataToVerify = tokenData.subdata(in: 0..<(tokenData.count - 32))
        let hmac = HMAC<SHA256>.authenticationCode(for: dataToVerify, using: SymmetricKey(data: signingKey))
        guard Data(hmac) == signature else {
            throw FernetError.signatureMismatch
        }
        
        // 2. AES-128-CBC Decryption
        // Note: CryptoKit doesn't support CBC directly, we use CommonCrypto via a helper
        guard let decryptedData = try decryptAES_CBC(key: encryptionKey, iv: iv, ciphertext: ciphertext) else {
            throw FernetError.decryptionFailed
        }
        
        // 3. Remove PKCS7 Padding
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw FernetError.decryptionFailed
        }
        
        return result
    }
    
    private static func decryptAES_CBC(key: Data, iv: Data, ciphertext: Data) throws -> Data? {
        let keyLength = key.count
        let validKeyLengths = [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256]
        guard validKeyLengths.contains(keyLength) else { return nil }
        
        let dataLength = ciphertext.count
        let bufferLength = dataLength + kCCBlockSizeAES128
        var buffer = Data(count: bufferLength)
        
        var numBytesDecrypted: Int = 0
        
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            ciphertext.withUnsafeBytes { ciphertextPtr in
                iv.withUnsafeBytes { ivPtr in
                    key.withUnsafeBytes { keyPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyLength,
                            ivPtr.baseAddress,
                            ciphertextPtr.baseAddress, dataLength,
                            bufferPtr.baseAddress, bufferLength,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytesDecrypted)
    }
}

// Helper to handle Base64 URLSafe encoding/decoding
extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
        }
        
        self.init(base64Encoded: base64)
    }
}

// CommonCrypto bridging definitions (stubs if not directly available, but usually are in Swift)
import CommonCrypto
