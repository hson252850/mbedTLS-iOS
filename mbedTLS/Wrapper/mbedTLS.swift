//
//  mbedTLS.swift
//  mbedTLS
//
//  Created by Siddarth Gandhi on 2/21/19.
//  Copyright © 2019 Siddarth Gandhi. All rights reserved.
//

import Foundation
import libmbedtls

public class mbedTLS {
    
    public enum HandshakeSteps: Int {
        case clientHello = 0
        case serverHello, serverCertificate, serverKeyExchange, serverCertificateRequest, serverHelloDone
        case clientCertificate, clientKeyExchange, certificateVerify, clientFinished
        case serverFinished
    }
    
    public enum SSLProtocolVersion: Int32 {
        case sslProtocol10 = 1
        case sslProtocol11 = 2
        case sslProtocol12 = 3
    }
    
    public enum DebugThresholdLevel: Int {
        case noDebug = 0, error, stateChange, informational, verbose
    }
    
    public static var sslContext: mbedtls_ssl_context!
    public static var sslConfig: mbedtls_ssl_config!
    public static var counterRandomByteGenerator: mbedtls_ctr_drbg_context!
    public static var entropy: mbedtls_entropy_context!
    
    public static var writeCallbackBuffer: [UInt8]?
    public static var readCallbackBuffer: [UInt8]?
    
    public typealias sslWriteCallback = (UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int) ->  Int32
    public typealias sslReadCallback = (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int) ->  Int32
    
    static var sslWriteCallbackFunc: sslWriteCallback!
    static var sslReadCallbackFunc: sslReadCallback!
    
    public static var currentHandshakeState: HandshakeSteps = .clientHello
    
    static var ciphers: Array<Int32>!
    
    public static func setupSSLContext() {
        sslContext = mbedtls_ssl_context()
        sslConfig = mbedtls_ssl_config()
        counterRandomByteGenerator = mbedtls_ctr_drbg_context()
        entropy = mbedtls_entropy_context()
        
        mbedtls_ssl_init(&sslContext)
        mbedtls_ssl_config_init(&sslConfig)
        mbedtls_ctr_drbg_init(&counterRandomByteGenerator)
        mbedtls_entropy_init(&entropy)
        
        if mbedtls_ctr_drbg_seed(&counterRandomByteGenerator, mbedtls_entropy_func, &entropy, nil, 0) != 0 {
            print("mbedtls_ctr_drbg_seed failed!")
            return
        }
        
        if mbedtls_ssl_config_defaults(&sslConfig, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT) != 0 {
            print("mbedtls_ssl_config_defaults failed!")
            return
        }
        
        mbedtls_ssl_conf_rng(&sslConfig, mbedtls_ctr_drbg_random, &counterRandomByteGenerator)

        if mbedtls_ssl_setup(&sslContext, &sslConfig) != 0 {
            print("mbedtls_ssl_setup failed!")
            return
        }
    }
    
    public static func setIOFuncs(contextParameter: inout String, _ read: @escaping sslReadCallback, _ write: @escaping sslWriteCallback) {
        sslReadCallbackFunc = read
        sslWriteCallbackFunc = write
        
        mbedtls_ssl_set_bio(&sslContext, &contextParameter, { mbedTLS.sslWriteCallbackFunc($0, $1, $2) }, { mbedTLS.sslReadCallbackFunc($0, $1, $2) }, nil)
    }
    
    public static func configureCipherSuites(_ cipherSuites: [Int32]) {
        mbedTLS.ciphers = cipherSuites
        mbedtls_ssl_conf_ciphersuites(&sslConfig, &mbedTLS.ciphers)
    }
    
    public static func setMinimumProtocolVersion(_ version: SSLProtocolVersion) {
        mbedtls_ssl_conf_min_version(&sslConfig, MBEDTLS_SSL_MAJOR_VERSION_3, version.rawValue)
    }
    
    public static func setMaximumProtocolVersion(_ version: SSLProtocolVersion) {
        mbedtls_ssl_conf_max_version(&sslConfig, MBEDTLS_SSL_MAJOR_VERSION_3, version.rawValue)
    }
    
    public static func enableDebugMessages(level: DebugThresholdLevel) {
        mbedtls_debug_set_threshold(Int32(level.rawValue))
        mbedtls_ssl_conf_dbg(&sslConfig, debug_msg, stdout)
    }
    
    public static func executeNextHandshakeStep() -> [UInt8]? {
        mbedTLS.writeCallbackBuffer = nil
        
        if mbedTLS.currentHandshakeState == .serverFinished {
            return nil
        }
        
        if mbedTLS.currentHandshakeState == .clientHello {
            mbedtls_ssl_handshake_client_step(&sslContext)
            mbedtls_ssl_handshake_client_step(&sslContext)
            mbedTLS.currentHandshakeState = HandshakeSteps(rawValue: mbedTLS.currentHandshakeState.rawValue + 1)!
        } else {
            mbedtls_ssl_handshake_client_step(&sslContext)
            mbedTLS.currentHandshakeState = HandshakeSteps(rawValue: mbedTLS.currentHandshakeState.rawValue + 1)!
        }
        
        return mbedTLS.writeCallbackBuffer
    }
    
}