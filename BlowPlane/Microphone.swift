//
//  Microphone.swift
//  BlowPlane
//


import Foundation
import AVFoundation

class Microphone: NSObject {
    private var session: AVAudioSession!
    private var recorder: AVAudioRecorder!
    
    var power: Float {
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }
    
    override init() {
        super.init()
        
        session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            session.requestRecordPermission() { allowed in
                if !allowed {
                    print("warning: record permission declined")
                    // TODO display this to the user
                }
            }
        } catch {
            fatalError("could not activate audio session")
        }
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            
            recorder.delegate = self
        } catch {
            fatalError("could not create audio recorder")
        }
    }
    
    func startRecording() {
        recorder.record()
    }
    
    func cleanUp() {
        recorder.deleteRecording()
    }
    
    private var documentsDirectoryURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    private var recordingURL: URL {
        documentsDirectoryURL.appendingPathComponent("blow.caf")
    }
}

extension Microphone: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        fatalError("audio recorder encode error")
    }
}

extension Microphone {
    /// applies normalization so the output is roughly between 0 and 1
    var normalizedPower: Float {
        (power + 30) / 30
    }
}
