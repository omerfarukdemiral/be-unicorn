import Foundation
import AVFoundation
import AudioToolbox

/// Hafif, asset'siz UI sesi.
///
/// Gerçek SFX/müzik asset'i bu ortamda üretmek zor olduğundan, sesler AVAudioEngine ile
/// çalışma anında üretilen kısa tonlardan (sine + zarf) oluşur. Tek bir paylaşılan engine
/// + oynatıcıyla her efekt için ufak bir PCM buffer sentezlenir. Toggle UserDefaults'ta
/// saklanır (GameState'e DOKUNULMAZ).
@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private let defaultsKey = "unicorn.soundEnabled"
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var format: AVAudioFormat!
    private var started = false

    /// Sesin açık/kapalı durumu (UserDefaults'ta kalıcı). Kapalıyken hiçbir ton çalmaz.
    private(set) var isEnabled: Bool

    private init() {
        // Varsayılan: açık. (Daha önce hiç ayarlanmadıysa true.)
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: defaultsKey)
        }
    }

    // MARK: - Kurulum / lifecycle (UnicornApp + ContentView çağırır)

    /// Uygulama başında bir kez: audio session + engine kur. Hata sessizce yutulur (ses kritik değil).
    func configure() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // .ambient: sessiz anahtarına saygı duy, arka plan müziğini kesme.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            player.play()
            started = true
        } catch {
            started = false   // sentez başarısız → sistem sesine düşeriz
        }
    }

    /// Arka plana geçince engine'i duraklat (pil/CPU). Foreground'da resume.
    func pause() {
        guard started else { return }
        engine.pause()
    }

    func resume() {
        guard started else { return }
        do {
            try engine.start()
            player.play()
        } catch { /* sessiz */ }
    }

    // MARK: - Toggle

    /// Sesi aç/kapa (UI ayar toggle'ı bunu çağırır). Kalıcıdır.
    func setEnabled(_ on: Bool) {
        isEnabled = on
        UserDefaults.standard.set(on, forKey: defaultsKey)
        if on { tap() }   // küçük onay dokunuşu
    }

    @discardableResult
    func toggle() -> Bool {
        setEnabled(!isEnabled)
        return isEnabled
    }

    // MARK: - Anlamsal efektler (GameModel/UI çağırır)

    /// İşe alım / eşya alımı / hafif onay — kısa yumuşak "tık".
    func tap() { play(tones: [Tone(freq: 660, dur: 0.05, gain: 0.18)]) }

    /// Tab/seçim — çok kısa nötr tık.
    func select() { play(tones: [Tone(freq: 880, dur: 0.03, gain: 0.12)]) }

    /// Karar geldi — dikkat çeken çift nota (yükselen).
    func decision() {
        play(tones: [Tone(freq: 520, dur: 0.06, gain: 0.16),
                     Tone(freq: 780, dur: 0.07, gain: 0.16)])
    }

    /// Günlük/sprint başarı — neşeli yükselen üçlü.
    func success() {
        play(tones: [Tone(freq: 660, dur: 0.07, gain: 0.18),
                     Tone(freq: 880, dur: 0.07, gain: 0.18),
                     Tone(freq: 1320, dur: 0.12, gain: 0.20)])
    }

    /// Çeyrek / büyük kapanış — başarıdan biraz daha tok, dört nota.
    func close() {
        play(tones: [Tone(freq: 523, dur: 0.08, gain: 0.18),
                     Tone(freq: 659, dur: 0.08, gain: 0.18),
                     Tone(freq: 784, dur: 0.08, gain: 0.18),
                     Tone(freq: 1047, dur: 0.16, gain: 0.22)])
    }

    /// Funding turu / sezon finali / win — görkemli arpej (uzun finiş).
    func celebrate() {
        play(tones: [Tone(freq: 523, dur: 0.09, gain: 0.20),
                     Tone(freq: 659, dur: 0.09, gain: 0.20),
                     Tone(freq: 784, dur: 0.09, gain: 0.20),
                     Tone(freq: 1047, dur: 0.10, gain: 0.22),
                     Tone(freq: 1319, dur: 0.22, gain: 0.24)])
    }

    /// Kritik uyarı (düşük runway, istifa) — alçak iki nota (düşen).
    func warning() {
        play(tones: [Tone(freq: 440, dur: 0.10, gain: 0.18),
                     Tone(freq: 330, dur: 0.14, gain: 0.18)])
    }

    /// İflas / başarısız sonuç — boğuk düşen üçlü.
    func failure() {
        play(tones: [Tone(freq: 392, dur: 0.12, gain: 0.20),
                     Tone(freq: 294, dur: 0.14, gain: 0.20),
                     Tone(freq: 196, dur: 0.26, gain: 0.22)])
    }

    // MARK: - Sentez

    private struct Tone {
        let freq: Double   // Hz
        let dur: Double    // saniye
        let gain: Double   // 0-1 tepe genlik
    }

    /// Toleranslı oynatma: engine hazırsa sentezlenmiş tonu çal, değilse sistem sesine düş.
    private func play(tones: [Tone]) {
        guard isEnabled else { return }
        guard started, let format, let buffer = buffer(for: tones, format: format) else {
            // Yedek: hafif sistem klik sesi (sentez kurulamadıysa).
            AudioServicesPlaySystemSound(1104)
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    /// Ardışık tonları tek bir PCM buffer'a sentezle (her tonda kısa attack/decay zarfı).
    private func buffer(for tones: [Tone], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let totalDur = tones.reduce(0) { $0 + $1.dur }
        let frameCount = AVAudioFrameCount(totalDur * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var frame = 0
        for tone in tones {
            let toneFrames = Int(tone.dur * sampleRate)
            let twoPiF = 2.0 * Double.pi * tone.freq
            // Yumuşak zarf: hızlı attack, üstel decay → "tık/çın" hissi (clicksiz).
            let attack = Double(toneFrames) * 0.1
            for n in 0..<toneFrames {
                guard frame < Int(frameCount) else { break }
                let t = Double(n) / sampleRate
                let envelope: Double
                if Double(n) < attack {
                    envelope = Double(n) / max(1, attack)
                } else {
                    let p = Double(n - Int(attack)) / Double(max(1, toneFrames - Int(attack)))
                    envelope = exp(-3.0 * p)
                }
                channel[frame] = Float(sin(twoPiF * t) * tone.gain * envelope)
                frame += 1
            }
        }
        return buffer
    }
}
