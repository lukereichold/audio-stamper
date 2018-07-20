import AudioKit
import AudioKitUI
import UIKit

class ViewController: UIViewController {

    var micMixer: AKMixer!
    var recorder: AKNodeRecorder!
    var player: AKPlayer!
    var tape: AKAudioFile!
    var micBooster: AKBooster!
    var mainMixer: AKMixer!

    var amplitudeTracker: AKAmplitudeTracker!
    let mic = AKMicrophone()

    var state = State.readyToRecord {
        didSet {
            // coming soon

        }
    }

    @IBOutlet private var plot: AKNodeOutputPlot?
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var resetButton: UIButton!
    @IBOutlet private weak var mainButton: UIButton!
    @IBOutlet private weak var loopButton: UIButton!

    enum State {
        case readyToRecord
        case recording
        case readyToPlay
        case playing
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        AKAudioFile.cleanTempDirectory()

        // Session settings
        AKSettings.bufferLength = .medium

        do {
            try AKSettings.setSession(category: .playAndRecord, with: .allowBluetoothA2DP)
        } catch {
            AKLog("Could not set session category.")
        }

        AKSettings.defaultToSpeaker = true

        // Patching
        micMixer = AKMixer(mic)
        micBooster = AKBooster(micMixer)

        // Will set the level of microphone monitoring
        micBooster.gain = 0
        recorder = try? AKNodeRecorder(node: micMixer)
        if let file = recorder.audioFile {
            player = AKPlayer(audioFile: file)
        }
        player.isLooping = true
        player.completionHandler = playingEnded

        amplitudeTracker = AKAmplitudeTracker(player)
        AudioKit.output = amplitudeTracker

        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        plot?.shouldFill = true
        plot?.shouldMirror = true
        plot?.node = mic
        setupButtonNames()
        setupUIForRecording()
    }

    func playingEnded() {
        DispatchQueue.main.async {
            self.setupUIForPlaying()
        }
    }

    @IBAction func mainButtonTouched(sender: UIButton) {
        switch state {

        // START RECORDING
        case .readyToRecord:
            statusLabel.text = "Recording"
            mainButton.setTitle("Stop", for: .normal)
            state = .recording
            // microphone will be monitored while recording
            // only if headphones are plugged
            if AKSettings.headPhonesPlugged {
                micBooster.gain = 1
            }
            do {
                try recorder.record()
            } catch { print("Error while attempting to start recording.") }

        // STOP RECORDING
        case .recording:
            // Microphone monitoring is muted
            micBooster.gain = 0
            tape = recorder.audioFile!
            player.load(audioFile: tape)

            if let _ = player.audioFile?.duration {
                recorder.stop()
                tape.exportAsynchronously(name: "TempTestFile.m4a",
                                          baseDir: .documents,
                                          exportFormat: .m4a) {_, exportError in
                                            if let error = exportError {
                                                print("Export Failed \(error)")
                                            } else {
                                                print("Export succeeded")
                                            }
                }
                setupUIForPlaying()
            }

        // PLAY
        case .readyToPlay:
            player.play()
            statusLabel.text = "Playing..."
            mainButton.setTitle("Stop", for: .normal)
            state = .playing
            plot?.node = player

        // STOP PLAYING
        case .playing:
            player.stop()
            setupUIForPlaying()
            plot?.node = mic
        }
    }

    struct Constants {
        static let empty = ""
    }

    func setupButtonNames() {
        resetButton.setTitle(Constants.empty, for: UIControlState.disabled)
        mainButton.setTitle(Constants.empty, for: UIControlState.disabled)
        loopButton.setTitle(Constants.empty, for: UIControlState.disabled)
    }

    func setupUIForRecording() {
        state = .readyToRecord
        statusLabel.text = "Ready to record"
        mainButton.setTitle("Record", for: .normal)
        resetButton.isEnabled = false
        resetButton.isHidden = true
        micBooster.gain = 0
        loopButton.isEnabled = false
    }

    func setupUIForPlaying() {
        let recordedDuration = player != nil ? player.audioFile?.duration  : 0
        statusLabel.text = "Recorded: \(String(format: "%0.1f", recordedDuration!)) seconds"
        mainButton.setTitle("Play", for: .normal)
        state = .readyToPlay
        resetButton.isHidden = false
        resetButton.isEnabled = true
        loopButton.isEnabled = true
    }

    @IBAction func loopButtonTouched(sender: UIButton) {

        if player.isLooping {
            player.isLooping = false
            sender.setTitle("Loop is Off", for: .normal)
        } else {
            player.isLooping = true
            sender.setTitle("Loop is On", for: .normal)
        }
    }

    @IBAction func resetButtonTouched(sender: UIButton) {
        player.stop()
        plot?.node = mic
        do {
            try recorder.reset()
        } catch { print("Errored resetting.") }

        //try? player.replaceFile((recorder.audioFile)!)
        setupUIForRecording()
    }

}
