//
//  AudioEngineViewController.swift
//  MediaPlayground
//
//  Created by Nouf Alloboon on 23/06/1447 AH.
//

import UIKit
import AVFoundation

class AudioEngineViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    
    
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var currentTimeLaabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    
    @IBOutlet weak var volumeSlider: UISlider!
    
    @IBOutlet weak var bassSlider: UISlider!
    @IBOutlet weak var bassValueLabel: UILabel!
    
    @IBOutlet weak var midSlider: UISlider!
    @IBOutlet weak var midValueLabel: UILabel!
    
    @IBOutlet weak var trebleSlider: UISlider!
    @IBOutlet weak var trebleValueLabel: UILabel!
    
    
    
    // MARK: - Audio Engine
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 3)
    
    private var audioFile: AVAudioFile?
    
    
    // MARK: - Playback State
    
    private var isPlaying = false
    private var isSeeking = false
    private var isPaused = false
    
    private var durationSeconds: Double = 0
    private var totalFrames: AVAudioFramePosition = 0
    private var sampleRate: Double = 44100
    private var uiTimer: Timer?
    private var seekBaseFrame: AVAudioFramePosition = 0

    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Audio FX"
        setupUI()
        setupAudioSession()
        loadAudtoFromBundle()
        setupEngineGraph()
        prepareDurationUI()
    }
    
    deinit {
        stopUITimer()
    }

    // MARK: - UI Setup
    
    private func setupUI() {
        
        // Progress UI
        currentTimeLaabel.text = "00 : 00"
        durationLabel.text = "00 : 00"
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.value = 0
        progressSlider.isContinuous = true
        
        
        // Volume
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        
        
        // EQ sliders range (dB)
        [bassSlider, midSlider, trebleSlider].forEach {
            $0?.minimumValue = -12
            $0?.maximumValue = 12
            $0?.value = 0
        }
        updateEQValueLabels()
        updateButtonsUI()
        
    }

    private func updateEQValueLabels() {
        
        bassValueLabel.text = String(format: "%.1f dB", bassSlider.value)
        midValueLabel.text = String(format: "%.1f dB", midSlider.value)
        trebleValueLabel.text = String(format: "%.1f dB", trebleSlider.value)
        
    }
    
    private func updateButtonsUI() {

        let playSymbol = isPlaying ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: playSymbol), for: .normal)

        let stopSymbol = "arrow.counterclockwise"   // Reset
        stopButton.setImage(UIImage(systemName: stopSymbol), for: .normal)

    }
    
    
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
        
    }
    
    
    
    
    // MARK: - Engine Graph (Player -> EQ -> MainMixer -> Output)
    
    private func setupEngineGraph() {
        
        engine.attach(playerNode)
        engine.attach(eq)
        
        // 3 bands setup: Bass / Mid / Treble
        
        // band[0] = Bass
        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 100
        eq.bands[0].bandwidth = 1.0
        eq.bands[0].gain = 0
        eq.bands[0].bypass = false

        
        // band[1] = Mid
        eq.bands[1].filterType = .parametric
        eq.bands[1].frequency = 1000
        eq.bands[1].bandwidth = 1.0
        eq.bands[1].gain = 0
        eq.bands[1].bypass = false
        
        // band[2] = Treble
        eq.bands[2].filterType = .highShelf
        eq.bands[2].frequency = 8000
        eq.bands[2].bandwidth = 1.0
        eq.bands[2].gain = 0
        eq.bands[2].bypass = false
        
        eq.bypass = false
        eq.globalGain = 0
        
        // Nodes connection
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        
        // Volume (Mixer)
        engine.mainMixerNode.outputVolume = volumeSlider.value
        
    }

    
    
    // MARK: - Load Audio
    
    private func loadAudtoFromBundle() {
        
        
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") ?? Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            print("Audio file not found in bundle.")
            return
        }
        
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("AVAudioFile error:", error)
        }
        
    }
    
    
    
    // MARK: - Duration UI
    
    private func prepareDurationUI() {
        
        guard let file = audioFile else {return}
        
        totalFrames = file.length
        sampleRate = file.processingFormat.sampleRate
        durationSeconds = Double(totalFrames) / sampleRate
        
        durationLabel.text = formatTime(durationSeconds)
        currentTimeLaabel.text = " 00 : 00 "
        progressSlider.value = 0
        
        seekBaseFrame = 0
        
    }
    
    private func formatTime(_ seconds: Double) -> String {
        
        guard seconds.isFinite, seconds >= 0 else { return " 00 : 00 "}
        
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d: %02d", minutes, secs)
    }
    
    // MARK: - Play Helpers
    
    private func startEngineIfNeeded() {
        
        guard !engine.isRunning else {return}
        
        do {
            try engine.start()
        } catch {
            print("Engine start error:", error)
        }
        
    }
    
    
    private func scheduleFrom(frame startFrame: AVAudioFramePosition) {
        
        guard let file = audioFile else {return}
        
        playerNode.stop()
        
        let remaimingFrame = max(0, totalFrames - startFrame)
        let frameCount = AVAudioFrameCount(remaimingFrame)
        
        seekBaseFrame = startFrame
        
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil, completionHandler: nil)
        
    }
    
    
    private func currentFramePosition() -> AVAudioFramePosition {
        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return seekBaseFrame
        }

        let playedFrames = AVAudioFramePosition(playerTime.sampleTime)
        return seekBaseFrame + playedFrames
    }
    
    
    // MARK: - UI Timer

    private func startUITimer() {
        
        stopUITimer()
        
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {[weak self] _ in self?.updateProgressUI()}
        
        RunLoop.main.add(uiTimer! , forMode: .common)
        
    }
    
    
    private func stopUITimer() {
        
        uiTimer?.invalidate()
        uiTimer = nil
        
    }
    
    
    private func updateProgressUI() {
        
        guard !isSeeking else {return}
        guard durationSeconds > 0 else {return}
        guard isPlaying else {return}
        
        if let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            
            let playedFrames = AVAudioFramePosition(playerTime.sampleTime)
            var currentFrame = seekBaseFrame + playedFrames
            
            currentFrame = max(0, min(currentFrame, totalFrames))
            
            let currentSeconds = Double(currentFrame) / sampleRate
            currentTimeLaabel.text = formatTime(currentSeconds)
            
            let progress = Float(currentSeconds / durationSeconds)
            progressSlider.value = min(max(progress, 0), 1)
            
            if currentFrame >= totalFrames {
                isPlaying = false
                stopUITimer()
                currentTimeLaabel.text = durationLabel.text
                progressSlider.value = 1
            }
            
        }
        
    }
    
    
    // MARK: - Actions




    
    @IBAction func playTapped(_ sender: UIButton) {
        
        guard audioFile != nil else { return }

        startEngineIfNeeded()

        if isPlaying {
            // Pause
            seekBaseFrame = currentFramePosition()
            playerNode.pause()
            isPlaying = false
            isPaused = true
            stopUITimer()
            updateButtonsUI()
            return
        }

        // Play / Resume
        scheduleFrom(frame: seekBaseFrame)
        playerNode.play()
        isPlaying = true
        isPaused = false
        startUITimer()
        updateButtonsUI()
        
    }
    
    @IBAction func stopTapped(_ sender: UIButton) {

        playerNode.stop()
        stopUITimer()

        isPlaying = false
        isPaused = false
        isSeeking = false

        
        seekBaseFrame = 0
        progressSlider.value = 0
        currentTimeLaabel.text = " 00 : 00 "
        
        
//        seekBaseFrame = min(currentFramePosition(), totalFrames)
//
//        playerNode.pause()
//
//        isPlaying = false
//        stopUITimer()
//
//        let seconds = Double(seekBaseFrame) / sampleRate
//        currentTimeLaabel.text = formatTime(seconds)
//        progressSlider.value = Float(seconds / durationSeconds)
        
        
        
    }
    
    
    @IBAction func progressChanged(_ sender: UISlider) {
        
        guard audioFile != nil else {return}
        guard durationSeconds > 0 else {return}
        
        let targetFrame = AVAudioFramePosition(Double(sender.value) * Double(totalFrames))
        
        isSeeking = true
        scheduleFrom(frame: targetFrame)
        
        if isPlaying {
            playerNode.play()
        }
        
        seekBaseFrame = targetFrame
        isSeeking = false
        
        let currentSeconds = Double(targetFrame) / sampleRate
        currentTimeLaabel.text = formatTime(currentSeconds)
        
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        
        engine.mainMixerNode.outputVolume = sender.value
        
    }
    
    
    @IBAction func bassChanged(_ sender: UISlider) {
        
        eq.bands[0].gain = sender.value
        updateEQValueLabels()
        
    }
    
    
    @IBAction func midChanged(_ sender: UISlider) {
        
        eq.bands[1].gain = sender.value
        updateEQValueLabels()
        
    }
    
    @IBAction func trebleChanged(_ sender: UISlider) {
        
        eq.bands[2].gain = sender.value
        updateEQValueLabels()
        
    }
    
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
