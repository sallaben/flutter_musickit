import Flutter
import UIKit
import StoreKit
import MediaPlayer

enum FlutterErrorCode {
    static let unavailable = "UNAVAILABLE"
    static let denied = "DENIED"
    static let notDetermined = "NOT DETERMINED"
}

enum AuthorizationStatusCodes {
    static let authorized = "AUTHORIZED"
    static let not_determined = "NOT_DETERMINED"
    static let denied = "DENIED"
    static let restricted = "RESTRICTED"
    static let unknown = "UNKNOWN"
}

public class SwiftMusickitPlugin: NSObject, FlutterPlugin {
    let systemMusicPlayer = MPMusicPlayerController.systemMusicPlayer
    var storefrontCountryCode = "us"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "musickit", binaryMessenger: registrar.messenger())
        let instance = SwiftMusickitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 11.0, *) {
            switch call.method {
                case "checkAppleMusicAuthorizationStatus":
                    checkAppleMusicAuthorizationStatus(result: result)
                case "appleMusicRequestPermission":
                    appleMusicRequestPermission(result: result)
                case "appleMusicCheckIfDeviceCanPlayback":
                    appleMusicCheckIfDeviceCanPlayback(result: result)
                case "fetchUserToken":
                    fetchUserToken(developerToken: call.arguments as! String, result: result)
                case "appleMusicPlayTrackId":
                    appleMusicPlayTrackId(ids: call.arguments as! [String], result: result)
                default:
                    result(FlutterMethodNotImplemented)
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 11.0, *)
    func checkAppleMusicAuthorizationStatus(result: @escaping FlutterResult) {
        let authorizationStatus = _checkAppleMusicAuthorizationStatus();
        switch(authorizationStatus) {
            case AuthorizationStatusCodes.authorized:
                result(true)
            case AuthorizationStatusCodes.not_determined:
                result(false)
            case AuthorizationStatusCodes.denied:
                result(false)
            case AuthorizationStatusCodes.restricted:
                result(false)
            default:
               result(FlutterError(code: "UNKNOWN_RESPONSE", message: "Unknown response from Apple Music", details: "SKCloudServiceController.authorizationStatus()"))
        }
    }
    
    @available(iOS 11.0, *)
    func _checkAppleMusicAuthorizationStatus() -> String {
        switch SKCloudServiceController.authorizationStatus() {
            case .authorized:
                // The user's already authorized - we don't need to do anything more here, so we'll exit early.
                requestStorefrontCountryCode(serviceController: SKCloudServiceController());
                return AuthorizationStatusCodes.authorized
            case .notDetermined:
                return AuthorizationStatusCodes.not_determined
            case .denied:
                // The user has selected 'Don't Allow' in the past - so we're going to show them a different dialog to push them through to their Settings page and change their mind, and exit the function early.
                return AuthorizationStatusCodes.denied
                // TODO: Show an alert to guide users into the Settings
            case .restricted:
                // User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied.
                return AuthorizationStatusCodes.restricted
            @unknown default:
                return AuthorizationStatusCodes.unknown
        }
    }

    @available(iOS 11.0, *)
    func appleMusicRequestPermission(result: @escaping FlutterResult) {
        _ = _checkAppleMusicAuthorizationStatus();
        SKCloudServiceController.requestAuthorization { (status:SKCloudServiceAuthorizationStatus) in
            switch status {
                case .authorized:
                    // All good - the user tapped 'OK', so you're clear to move forward and start playing.
                    self.requestStorefrontCountryCode(serviceController: SKCloudServiceController());
                    result("Successfully Authorized")
                case .denied:
                    // The user tapped 'Don't allow'.
                    result(FlutterError(code: FlutterErrorCode.denied, message: "User denied permission", details: "The user tapped 'Don't allow'"))
                case .notDetermined:
                    // The user hasn't decided or it's not clear whether they've confirmed or denied.
                    result(FlutterError(code: FlutterErrorCode.notDetermined, message: "Not determined if confirmed or denied", details: "The user hasn't decided or it's not clear whether they've confirmed or denied."))
                case .restricted:
                    // User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied.
                    result(FlutterError(code: FlutterErrorCode.unavailable, message: "User may be restricted", details: "User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied."))
                @unknown default:
                    result(FlutterError(code: "UNKNOWN", message: "Other Error", details: "Not Known"))
            }
        }
    }
    
    @available(iOS 11.0, *)
    func requestStorefrontCountryCode(serviceController: SKCloudServiceController) {
        let completionHandler: (String?, Error?) -> Void = { [weak self] (countryCode, error) in
            guard error == nil else {
                print("An error occurred when requesting storefront country code: \(error!.localizedDescription)")
                return
            }
            guard let countryCode = countryCode else {
                print("Unexpected value from SKCloudServiceController for storefront country code.")
                return
            }
            self?.storefrontCountryCode = countryCode
        }
        if SKCloudServiceController.authorizationStatus() == .authorized {
            serviceController.requestStorefrontCountryCode(completionHandler: completionHandler)
        }
    }

    // Check if the device is capable of playback
    @available(iOS 11.0, *)
    func appleMusicCheckIfDeviceCanPlayback(result: @escaping FlutterResult) {
        let serviceController = SKCloudServiceController()
        serviceController.requestCapabilities { (capability: SKCloudServiceCapability, err: Error?) in
            if (err != nil) {
                result(FlutterError(code: FlutterErrorCode.unavailable, message: "Error Encountered", details: err.debugDescription))
            }
            switch capability {
                case SKCloudServiceCapability.musicCatalogPlayback:
                    // The user has an Apple Music subscription and can playback music!
                    result("Apple Music subscription found")
                case SKCloudServiceCapability.addToCloudMusicLibrary:
                    // The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library
                    result("Apple Music subscription found")
                default:
                    // The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?
                    result(FlutterError(code: FlutterErrorCode.unavailable, message: "Apple Music subscription not available", details: nil))
                    break
            }
        }
    }
    
    // Get Apple Music User Token
    @available(iOS 11.0, *)
    func fetchUserToken(developerToken : String, result: @escaping FlutterResult) {
        let serviceController = SKCloudServiceController()
        requestStorefrontCountryCode(serviceController: serviceController)
        serviceController.requestUserToken(forDeveloperToken: developerToken) { (userToken, err) in
            if (err != nil) {
                result(FlutterError(code: FlutterErrorCode.unavailable, message: "Error Encountered", details: err.debugDescription))
            } else {
                result(userToken)
            }
        }
    }
    
    @available(iOS 11.0, *)
    func appleMusicPlayTrackId(ids:[String], result: FlutterResult) {
        systemMusicPlayer.setQueue(with: ids)
        systemMusicPlayer.play()
    }
}
