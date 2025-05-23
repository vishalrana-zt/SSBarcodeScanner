//
//  SSNewBarCodeScanner.swift
//  BarcodeDemo
//
//  Created by Harshit on 25/11/24.
//

//
//  SwiftQRScanner.swift
//
import Foundation
import AVFoundation
import UIKit

/*
 This protocol defines methods which get called when some events occures.
 */
@objc public protocol SSScannerCodeDelegate: AnyObject {
    
    @objc func qrScanner(_ controller: UIViewController, scanDidComplete result: String)
    @objc func qrScannerDidFail(_ controller: UIViewController,  error: String)
    @objc func qrScannerDidCancel(_ controller: UIViewController)
    @objc optional func linkAssetManuallyTapped()
}


@objc public class SSBarCodeScanner: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var squareView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var assetLinkButton: UIButton!
    @IBOutlet weak var heightScannerView: NSLayoutConstraint!
    @IBOutlet weak var widthScannerView: NSLayoutConstraint!
    @IBOutlet weak var lblAlignDesc: UILabel!
    
    private var captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var isTorchOn = false
    public var showLinkAssetButton:Bool = false
    
    @objc public weak var delegate: SSScannerCodeDelegate?
    
    public init() {
        // Find the resource bundle dynamically

//       let bundle = Bundle(for: SSBarCodeScanner.self)
        super.init(nibName: "SSBarCodeScanner", bundle: Bundle.module)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupUI()
        addButtons()
        let middleView = SSBarCodeSquareView()
        middleView.translatesAutoresizingMaskIntoConstraints = false
        middleView.sizeMultiplier = 0.4
        middleView.lineColor = .white
        middleView.lineWidth = 3

        self.view.addSubview(middleView)

        // Add constraints to match squareView's size and position
        NSLayoutConstraint.activate([
            middleView.centerXAnchor.constraint(equalTo: squareView.centerXAnchor),
            middleView.centerYAnchor.constraint(equalTo: squareView.centerYAnchor),
            middleView.widthAnchor.constraint(equalTo: squareView.widthAnchor),
            middleView.heightAnchor.constraint(equalTo: squareView.heightAnchor)
        ])

        // Trigger drawing
        middleView.setNeedsDisplay()
        
        NotificationCenter.default
            .removeObserver(
                self,
                name:UIDevice.orientationDidChangeNotification,
                object: nil
            )
        
        addMaskLayerToVideoPreviewLayer(rect: self.squareView.frame)
        flashButton.layer.cornerRadius = 20
        cancelButton.layer.cornerRadius = 20
        switchCameraButton.layer.cornerRadius = 20
        lblAlignDesc.text = self.localize("lbl_Align_Barcode")
        squareView.autoresizingMask = UIView.AutoresizingMask(rawValue: UInt(0.0))
    }
    
    @objc func handleDeviceOrientationChange() {
//        updatePreviewOrientation()
    }
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = videoPreviewView.bounds
        addMaskLayerToVideoPreviewLayer(rect: squareView.frame)
    }
    
    func addMaskLayerToVideoPreviewLayer(rect: CGRect) {
        // Remove any existing mask layers
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
        
        // Create a mask layer
        let maskLayer = CAShapeLayer()
        maskLayer.frame = view.bounds
        maskLayer.fillColor = UIColor(white: 0.0, alpha: 0.5).cgColor

        // Convert the rect to the view's coordinate system
        let convertedRect = videoPreviewView.convert(rect, to: view)

        // Create a path with the cut-out for the scanner area
        let path = UIBezierPath(rect: view.bounds)
        let clearPath = UIBezierPath(rect: convertedRect)
        path.append(clearPath)
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd // Ensures the inner path is clear

        // Add the mask layer above the video preview
        view.layer.insertSublayer(maskLayer, above: videoPreviewLayer)
        view.bringSubviewToFront(squareView)
        view.bringSubviewToFront(cancelButton)
        view.bringSubviewToFront(flashButton)
        view.bringSubviewToFront(switchCameraButton)
        view.bringSubviewToFront(assetLinkButton)
        view.bringSubviewToFront(lblAlignDesc)
    }

    func setupCaptureSession() {
        if #available(iOS 10.0, *) {
            guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                delegate?
                    .qrScannerDidFail(self, error: "No back camera available.")
                return
            }
            currentDevice = captureDevice
            
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                captureSession.addInput(input)
                currentDeviceInput = input
            } catch {
                delegate?.qrScannerDidFail(self, error: error.localizedDescription)
                return
            }
            
            let output = AVCaptureMetadataOutput()
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            if #available(iOS 15.4, *) {
                output.metadataObjectTypes = [
                    .qr,
                    .ean13,
                    .ean8,
                    .code128,
                    .code39,
                    .code93,
                    .code39Mod43,
                    .pdf417,
                    .aztec,
                    .microQR,
                    .gs1DataBar,
                    .microPDF417,
                    .gs1DataBarLimited,
                    .gs1DataBarExpanded,
                    .codabar
                ]
            } else {
                output.metadataObjectTypes = [
                    .qr,
                    .ean13,
                    .ean8,
                    .code128,
                    .code39,
                    .code93,
                    .code39Mod43,
                    .pdf417,
                    .aztec
                ]
            }
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewLayer?.frame = videoPreviewView.bounds
            videoPreviewLayer?.connection?.videoOrientation = .portrait
            if let videoPreviewLayer = videoPreviewLayer {
                videoPreviewView.layer.addSublayer(videoPreviewLayer)
            }
            heightScannerView.constant = UIDevice.current.userInterfaceIdiom == .phone ? 200 : 400
            widthScannerView.constant = UIDevice.current.userInterfaceIdiom == .phone ? 200 : 400
        } else {
            // Fallback on earlier versions
        }
        

    }

    
    func setupUI() {
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
    }
    
    func startScanning() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    @objc func cancelButtonTapped() {
        delegate?.qrScannerDidCancel(self)
        dismiss(animated: true, completion: nil)
    }
    
    @objc func flashButtonTapped() {
        
        toggleTorch()
    }
    
    @objc func switchCameraTapped() {
        toggleCamera()
    }
    
    func toggleTorch() {
        guard let device = currentDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isTorchOn ? .off : .on
            isTorchOn.toggle()
            self.flashButton.isSelected = isTorchOn
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error.localizedDescription)")
        }
    }
    
    func toggleCamera() {
        guard let currentInput = currentDeviceInput else { return }
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        let newCameraPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        if #available(iOS 10.0, *) {
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition) else {
                delegate?.qrScannerDidFail(self, error: "Camera not available.")
                captureSession.commitConfiguration()
                return
            }
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                captureSession.addInput(newInput)
                currentDeviceInput = newInput
                currentDevice = newDevice
            } catch {
                delegate?.qrScannerDidFail(self, error: error.localizedDescription)
            }
            captureSession.commitConfiguration()
        } else {
            // Fallback on earlier versions
        }
        
    
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            delegate?.qrScannerDidFail(self, error: "Could not read QR code.")
            return
        }
        
        delegate?.qrScanner(self, scanDidComplete: stringValue)
        stopScanning()
        dismiss(animated: true, completion: nil)
    }
    
    // Adds buttons to view which can we used as extra fearures
    func addButtons() {
        assetLinkButton.addTarget(self, action: #selector(assetLinkButtonTapped), for: .touchUpInside)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont
                .systemFont(
                    ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 16.0 : 13.0,
                    weight: .medium
                ),
            .foregroundColor: UIColor.white,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let title = NSMutableAttributedString(string: self.localize("lbl_Link_Asset_Manually"),attributes: titleAttr)
        assetLinkButton.setAttributedTitle(title, for: .normal)
        assetLinkButton.contentHorizontalAlignment = .center
        assetLinkButton.titleLabel?.adjustsFontSizeToFitWidth = true
        assetLinkButton.isHidden = !showLinkAssetButton
    }
    
    @objc func assetLinkButtonTapped(){
        if let defaultDevice = currentDevice, defaultDevice.torchMode == .on{
            self.toggleTorch()
        }
        self.dismiss(animated: true, completion: nil)
        delegate?.linkAssetManuallyTapped?()
    }
}

extension SSBarCodeScanner {
    public func localize(_ key: String) -> String {
        let lang = UserDefaults.standard.value(forKey: "selected-language") as? String ?? "en"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj") else {
            return NSLocalizedString(key, comment: "")
        }
        guard let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
