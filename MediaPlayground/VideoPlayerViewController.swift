//
//  VideoPlayerViewController.swift
//  MediaPlayground
//
//  Created by Nouf Alloboon on 25/05/1447 AH.
//

import UIKit
import AVKit

class VideoPlayerViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var PlayerContainerView: UIView!
    
    @IBOutlet weak var playPauseBUTTON: UIButton!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var currentTimeLabell: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    
    @IBOutlet weak var labelspeed: UILabel!
    @IBOutlet weak var speedStepper: UIStepper!
    
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var volumeSlider: UISlider!
    
    
    // MARK: - Properties

     private let player = AVPlayer()
     private var playerLayer: AVPlayerLayer?
     private var timeObserver: Any?
     private var isSeeking = false
     private var isPlaying = false


    private let videoURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "AVPlayer"
        
        //AVAudioSession
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)

        setupUI()
        setupPlayerLayer()
        preparePlayer()
        addTimeObserver()
    }
    
    override func viewDidLayoutSubviews() {
        playerLayer?.frame = PlayerContainerView.bounds
    }
    
    
    // MARK: - Setup
    
    private func setupUI(){
        
        //Time
        currentTimeLabell.text = "00:00"
        durationLabel.text = "00:00"
        
        //Progress Slider
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.value = 0
        
        //Speed
        labelspeed.text = "Speed x1.0"
        speedStepper.minimumValue = 0.5
        speedStepper.maximumValue = 2.0
        speedStepper.stepValue = 0.5
        speedStepper.value = 1.0
        
        //Volume
        volumeLabel.text = "Volume"
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        player.volume = 1
        
    }
    
    
    private func setupPlayerLayer() {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = PlayerContainerView.bounds
        PlayerContainerView.layer.addSublayer(layer)
        playerLayer = layer
    }
    
    
    private func preparePlayer() {
        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
    }
    
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in guard let self = self else {return}
            self.updateTimeAndSlider()
        }
    }
    
    
    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d: %02d", minutes, secs)
    }
    
    private func updateTimeAndSlider() {
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite else {return}
        
        let current = player.currentTime().seconds
        
        // Update the slider
        progressSlider.value = Float(current / duration)
        
        // Update current time
        currentTimeLabell.text = formatTime(current)
        durationLabel.text = formatTime(duration)
    }
    
    
    private func seek(by seconds: Double) {
        
        guard let item = player.currentItem else {return}
        
        let currentTime = item.currentTime().seconds
        let duration = item.duration.seconds
        
        // calculate the new time
        var newTime = currentTime + seconds
        
        if newTime < 0 {
            newTime = 0
        }
        
        if duration.isFinite, newTime > duration {
          newTime = duration
        }
        
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    
    
    
    
    // MARK: - Actions
    
    @IBAction func rewind5Tapped(_ sender: Any) {
        seek(by: -5)
    }
    
    @IBAction func playPauseTapped(_ sender: Any) {
        if isPlaying {
            //Pause
            player.pause()
            isPlaying = false
            //playPauseBUTTON.setTitle("Play", for: .normal)
            playPauseBUTTON.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
        else {
          //Play
            let rate = Float(speedStepper.value)
            player.play()
            player.rate = rate
            isPlaying = true
            //playPauseBUTTON.setTitle("Pause", for: .normal)
            playPauseBUTTON.setImage(UIImage(systemName: "pause.fill"), for: .normal)

        }
    }
    
    @IBAction func forward5Tapped(_ sender: Any) {
        seek(by: 5)
    }
    
    
    @IBAction func progressChanged(_ sender: UISlider) {
        
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite else {return}

        let newTime = Double(sender.value) * duration
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    @IBAction func speedChanged(_ sender: Any) {
        
        let value = speedStepper.value
        
        labelspeed.text = String(format: "Speed x%.1f", value)
        
        if isPlaying {
            player.rate = Float(value)
        }
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        
        player.volume = sender.value
        
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
